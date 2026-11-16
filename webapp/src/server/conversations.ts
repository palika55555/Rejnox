import { MAX_MESSAGE, parseCursor } from "./chat";
import type { Db, Tx } from "./db";
import { HttpError, pgCode } from "./errors";
import { MAX_PHOTO_BYTES, sniffImageType } from "./gyms";
import { isUuid, requireText, requireUuid, type Body } from "./validate";

// Chat: konverzácie tréner–klient, súkromné a skupinové. Oprávnenia stráži
// databáza (RLS a funkcie z migrácie 018), tu sa len skladajú dopyty a chyby.

/** Najviac správ v jednej odpovedi (staršie sa dočítavajú cez ?before=). */
export const PAGE_SIZE = 50;

/** Najviac zmenených správ pri priebežnom načítaní (?since=). */
const CHANGES_LIMIT = 200;

export const MAX_IMAGE_BYTES = MAX_PHOTO_BYTES;

/** Reakcie, ktoré databáza prijme (rovnaký zoznam ako v migrácii 018). */
export const REACTIONS = ["👍", "❤️", "😂", "😮", "😢", "🔥", "💪", "👏"] as const;

export type ConversationKind = "link" | "direct" | "group";

export type LastMessage = {
  kind: "text" | "image" | "system";
  body: string | null;
  sentAt: string;
  mine: boolean;
  senderName: string | null;
  deleted: boolean;
};

export type ConversationSummary = {
  id: string;
  kind: ConversationKind;
  title: string;
  /** Prepojenie tréner–klient (len pri kind = "link"). */
  linkId: string | null;
  /** Druhá strana pri súkromnej konverzácii a prepojení. */
  otherUserId: string | null;
  /** "trainer" / "client" pri prepojení, "trainer" / "member" pri súkromnej. */
  otherRole: string | null;
  canSend: boolean;
  muted: boolean;
  unread: number;
  memberCount: number;
  myRole: "admin" | "member";
  lastMessage: LastMessage | null;
};

export type Member = { id: string; name: string; role: "admin" | "member"; me: boolean; lastReadAt: string };

export type ConversationDetail = ConversationSummary & {
  members: Member[];
  /** Skupina má zapnutý vstup cez pozývací kód. */
  hasInvite: boolean;
  /** Pri súkromnej konverzácii: druhú stranu som zablokoval. */
  blocked: boolean;
};

export type ReplyPreview = {
  id: string;
  kind: string;
  body: string | null;
  senderName: string | null;
  deleted: boolean;
};

export type Message = {
  id: string;
  kind: "text" | "image" | "system";
  body: string | null;
  /** ISO čas s mikrosekundami (kurzor pre ?before=). */
  sentAt: string;
  /** Posledná zmena (kurzor pre ?since=). */
  updatedAt: string;
  edited: boolean;
  deleted: boolean;
  mine: boolean;
  senderId: string;
  senderName: string | null;
  replyTo: ReplyPreview | null;
  reactions: { emoji: string; count: number; mine: boolean }[];
};

export type MessagePage = {
  messages: Message[];
  canSend: boolean;
  /** Mená tých, čo práve píšu. */
  typing: string[];
  /** Dokedy ostatní členovia prečítali (pre „Videné“). */
  readBy: { userId: string; lastReadAt: string }[];
};

export type Contact = { id: string; name: string; role: string };

const notFound = () => new HttpError(404, "not_found", "Konverzácia sa nenašla.");
const messageNotFound = () => new HttpError(404, "message_not_found", "Správa sa nenašla.");

/** Chyby z databázových funkcií chatu → odpoveď pre appku. */
export function chatError(error: unknown, missing: () => HttpError = notFound): unknown {
  switch (pgCode(error)) {
    case "P0002":
      return missing();
    case "42501":
      return new HttpError(403, "chat_forbidden", "Na toto nemáš oprávnenie alebo sa sem už písať nedá.");
    case "23514":
      return new HttpError(400, "invalid_input", "Skontroluj zadané údaje.");
    case "54000":
      return new HttpError(409, "group_full", "Skupina je plná (najviac 100 ľudí).");
    default:
      return error;
  }
}

/** Spustí dopyt a chyby databázy preloží na odpovede pre appku. */
export async function guarded<T>(work: () => Promise<T>, missing?: () => HttpError): Promise<T> {
  try {
    return await work();
  } catch (error) {
    throw chatError(error, missing);
  }
}

// ---------------------------------------------------------------- vstupy

export function parseBody(body: Body): string {
  return requireText(body, "body", MAX_MESSAGE, "Správa");
}

export function optionalUuid(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  return requireUuid(value, field);
}

export function parseEmoji(body: Body): string | null {
  const emoji = body.emoji;
  if (emoji === null || emoji === undefined) return null;
  if (typeof emoji !== "string" || !(REACTIONS as readonly string[]).includes(emoji)) {
    throw new HttpError(400, "invalid_emoji", "Túto reakciu nepoznáme.");
  }
  return emoji;
}

export function parseUserIds(value: unknown, max = 99): string[] {
  if (!Array.isArray(value) || value.length > max || !value.every(isUuid)) {
    throw new HttpError(400, "invalid_members", `Vyber najviac ${max} ľudí.`);
  }
  return [...new Set(value)];
}

export type MessageCursor = { before: string | null; since: string | null };

export function parseMessageCursor(url: URL): MessageCursor {
  const before = parseCursor(url.searchParams.get("before"));
  const since = parseCursor(url.searchParams.get("since"));
  if (before && since) throw new HttpError(400, "invalid_cursor", "Použi len jeden z before / since.");
  return { before, since };
}

// ------------------------------------------------------------ konverzácie

/** Je prihlásený členom? Inak 404 (nevyzradí, že konverzácia existuje). */
async function requireMember(tx: Tx, convId: string): Promise<void> {
  const [row] = await tx.query<{ ok: boolean }>("SELECT member_joined_at($1::uuid) IS NOT NULL AS ok", [convId]);
  if (!row.ok) throw notFound();
}

const summaryColumns = `
  c.id::text AS id,
  c.kind::text AS kind,
  CASE WHEN c.kind = 'group' THEN c.title
       WHEN c.kind = 'link' AND t.trainer_id = $1::uuid THEN t.client_name
       ELSE coalesce(op.display_name, 'Používateľ') END AS title,
  c.trainer_client_id::text AS "linkId",
  CASE WHEN c.kind = 'group' THEN NULL ELSE o.user_id::text END AS "otherUserId",
  CASE WHEN c.kind = 'link' THEN CASE WHEN t.trainer_id = $1::uuid THEN 'client' ELSE 'trainer' END
       WHEN c.kind = 'direct' THEN op.role::text END AS "otherRole",
  can_send_message(c.id) AS "canSend",
  cm.muted,
  cm.role AS "myRole",
  (SELECT count(*)::int FROM conversation_members x WHERE x.conversation_id = c.id) AS "memberCount",
  (SELECT count(*)::int FROM messages m
   WHERE m.conversation_id = c.id AND m.sender_id <> $1::uuid AND m.sent_at > cm.last_read_at
     AND m.deleted_at IS NULL AND m.kind <> 'system') AS unread,
  (SELECT json_build_object('kind', m.kind, 'body', left(m.body, 200), 'sentAt', m.sent_at,
            'mine', m.sender_id = $1::uuid, 'senderName', sp.display_name, 'deleted', m.deleted_at IS NOT NULL)
   FROM messages m LEFT JOIN public_profiles sp ON sp.id = m.sender_id
   WHERE m.conversation_id = c.id ORDER BY m.sent_at DESC LIMIT 1) AS "lastMessage"`;

const summaryFrom = `
  FROM conversation_members cm
  JOIN conversations c ON c.id = cm.conversation_id
  LEFT JOIN trainer_clients t ON t.id = c.trainer_client_id
  LEFT JOIN LATERAL (
    SELECT user_id FROM conversation_members
    WHERE conversation_id = c.id AND user_id <> $1::uuid AND c.kind <> 'group' LIMIT 1
  ) o ON true
  LEFT JOIN public_profiles op ON op.id = o.user_id
  WHERE cm.user_id = $1::uuid`;

/**
 * Konverzácie prihláseného, najnovšie hore. Ku každému aktívnemu prepojeniu
 * tréner–klient sa konverzácia založí, aby bola v zozname aj bez správ.
 * Ukončené prepojenia a prázdne súkromné konverzácie od druhých sa nezobrazia.
 */
export function list(db: Db, userId: string): Promise<ConversationSummary[]> {
  return db.asUser(userId, async (tx) => {
    await tx.query(
      `SELECT link_conversation(t.id) FROM trainer_clients t
       WHERE t.status = 'linked' AND (t.trainer_id = $1::uuid OR t.client_user_id = $1::uuid)
         AND NOT EXISTS (SELECT 1 FROM conversations c WHERE c.trainer_client_id = t.id)`,
      [userId],
    );
    return tx.query<ConversationSummary>(
      `SELECT ${summaryColumns} ${summaryFrom}
         AND (c.last_message_at IS NOT NULL
              OR (c.kind = 'link' AND t.status = 'linked')
              OR c.kind = 'group'
              OR c.created_by = $1::uuid)
       ORDER BY coalesce(c.last_message_at, c.created_at) DESC`,
      [userId],
    );
  });
}

export function detail(db: Db, userId: string, convId: string): Promise<ConversationDetail> {
  return db.asUser(userId, async (tx) => {
    const [summary] = await tx.query<ConversationSummary & { hasInvite: boolean; blocked: boolean }>(
      `SELECT ${summaryColumns},
              c.invite_code_hash IS NOT NULL AS "hasInvite",
              EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id = $1::uuid AND b.blocked_id = o.user_id) AS blocked
       ${summaryFrom} AND c.id = $2::uuid`,
      [userId, convId],
    );
    if (!summary) throw notFound();
    const members = await tx.query<Member>(
      `SELECT cm.user_id::text AS id, coalesce(p.display_name, 'Používateľ') AS name, cm.role,
              cm.user_id = $2::uuid AS me, to_json(cm.last_read_at) #>> '{}' AS "lastReadAt"
       FROM conversation_members cm LEFT JOIN public_profiles p ON p.id = cm.user_id
       WHERE cm.conversation_id = $1::uuid
       ORDER BY cm.role, lower(p.display_name)`,
      [convId, userId],
    );
    return { ...summary, members };
  });
}

/** Konverzácia k prepojeniu tréner–klient (založí ju pri aktívnej spolupráci). */
export function forLink(db: Db, userId: string, linkId: string): Promise<{ id: string }> {
  return db.asUser(userId, async (tx) => {
    const [existing] = await tx.query<{ id: string }>(
      `SELECT c.id::text AS id FROM trainer_clients t JOIN conversations c ON c.trainer_client_id = t.id
       WHERE t.id = $1::uuid`,
      [linkId],
    );
    if (existing) return existing;
    const [row] = await guarded(() =>
      tx.query<{ id: string }>("SELECT link_conversation($1::uuid)::text AS id", [linkId]),
    );
    return row;
  });
}

/** Súkromná konverzácia s človekom, ktorého poznám (inak 403). */
export function direct(db: Db, userId: string, otherId: string): Promise<{ id: string }> {
  return db.asUser(userId, async (tx) => {
    const [row] = await guarded(() => tx.query<{ id: string }>("SELECT start_direct($1::uuid)::text AS id", [otherId]));
    return row;
  });
}

export function contacts(db: Db, userId: string): Promise<Contact[]> {
  return db.asUser(userId, (tx) =>
    tx.query<Contact>("SELECT id::text, display_name AS name, role::text AS role FROM chat_contacts()"),
  );
}

// ----------------------------------------------------------------- správy

const messageColumns = `
  m.id::text AS id, m.kind, m.body,
  to_json(m.sent_at) #>> '{}' AS "sentAt",
  to_json(m.updated_at) #>> '{}' AS "updatedAt",
  m.edited_at IS NOT NULL AS edited,
  m.deleted_at IS NOT NULL AS deleted,
  m.sender_id = $2::uuid AS mine,
  m.sender_id::text AS "senderId",
  p.display_name AS "senderName",
  CASE WHEN r.id IS NULL THEN NULL
       ELSE json_build_object('id', r.id, 'kind', r.kind, 'body', left(r.body, 140),
                              'senderName', rp.display_name, 'deleted', r.deleted_at IS NOT NULL) END AS "replyTo",
  coalesce((SELECT json_agg(json_build_object('emoji', x.emoji, 'count', x.n, 'mine', x.mine) ORDER BY x.n DESC, x.emoji)
            FROM (SELECT emoji, count(*)::int AS n, bool_or(user_id = $2::uuid) AS mine
                  FROM message_reactions WHERE message_id = m.id GROUP BY emoji) x), '[]') AS reactions`;

// Odpoveď na správu spred môjho príchodu do skupiny RLS skryje (r je null).
const messageFrom = `
  FROM messages m
  LEFT JOIN public_profiles p ON p.id = m.sender_id
  LEFT JOIN messages r ON r.id = m.reply_to
  LEFT JOIN public_profiles rp ON rp.id = r.sender_id`;

async function oneMessage(tx: Tx, userId: string, messageId: string): Promise<Message> {
  const [row] = await tx.query<Message>(`SELECT ${messageColumns} ${messageFrom} WHERE m.id = $1::uuid`, [
    messageId,
    userId,
  ]);
  if (!row) throw messageNotFound();
  return row;
}

/**
 * Správy v konverzácii, staršie hore.
 * - bez kurzora: posledných PAGE_SIZE,
 * - `before`: staršie (dočítanie histórie),
 * - `since`: všetko nové aj zmenené (úprava, zmazanie, reakcia) po tomto čase.
 * Načítanie posunie „prečítané“ po najnovšiu správu, ktorú appka dostala.
 */
export function messages(db: Db, userId: string, convId: string, cursor: MessageCursor): Promise<MessagePage> {
  return db.asUser(userId, async (tx) => {
    await requireMember(tx, convId);
    let rows: Message[];
    if (cursor.since) {
      rows = await tx.query<Message>(
        `SELECT ${messageColumns} ${messageFrom}
         WHERE m.conversation_id = $1::uuid AND m.updated_at > $3::timestamptz
         ORDER BY m.updated_at, m.id LIMIT ${CHANGES_LIMIT}`,
        [convId, userId, cursor.since],
      );
    } else {
      rows = await tx.query<Message>(
        `SELECT ${messageColumns} ${messageFrom}
         WHERE m.conversation_id = $1::uuid AND ($3::timestamptz IS NULL OR m.sent_at < $3::timestamptz)
         ORDER BY m.sent_at DESC, m.id DESC LIMIT ${PAGE_SIZE}`,
        [convId, userId, cursor.before],
      );
      rows.reverse();
    }

    if (!cursor.before && rows.length > 0) {
      await tx.query(
        "SELECT mark_conversation_read($1::uuid, (SELECT max(t) FROM unnest($2::timestamptz[]) AS t))",
        [convId, rows.map((m) => m.sentAt)],
      );
    }

    const [state] = await tx.query<{ canSend: boolean; typing: string[] | null; readBy: MessagePage["readBy"] | null }>(
      `SELECT can_send_message($1::uuid) AS "canSend",
              (SELECT array_agg(p.display_name ORDER BY p.display_name)
               FROM conversation_members cm JOIN public_profiles p ON p.id = cm.user_id
               WHERE cm.conversation_id = $1::uuid AND cm.user_id <> $2::uuid
                 AND cm.typing_until > clock_timestamp()) AS typing,
              (SELECT json_agg(json_build_object('userId', cm.user_id, 'lastReadAt', cm.last_read_at))
               FROM conversation_members cm
               WHERE cm.conversation_id = $1::uuid AND cm.user_id <> $2::uuid) AS "readBy"`,
      [convId, userId],
    );
    return { messages: rows, canSend: state.canSend, typing: state.typing ?? [], readBy: state.readBy ?? [] };
  });
}

/** Vloží správu. Oprávnenie (člen, aktívna spolupráca, blokovanie) overí RLS. */
async function insertMessage(
  tx: Tx,
  userId: string,
  convId: string,
  values: { kind: "text" | "image"; body: string | null; replyTo: string | null },
): Promise<string> {
  await requireMember(tx, convId);
  const [row] = await guarded(() =>
    tx.query<{ id: string }>(
      `INSERT INTO messages (conversation_id, sender_id, kind, body, reply_to)
       VALUES ($1::uuid, $2::uuid, $3, $4, $5::uuid)
       RETURNING id::text`,
      [convId, userId, values.kind, values.body, values.replyTo],
    ),
  );
  return row.id;
}

export function send(
  db: Db,
  userId: string,
  convId: string,
  input: { body: string; replyTo: string | null },
): Promise<Message> {
  return db.asUser(userId, async (tx) => {
    const id = await insertMessage(tx, userId, convId, { kind: "text", ...input });
    return oneMessage(tx, userId, id);
  });
}

export function sendImage(
  db: Db,
  userId: string,
  convId: string,
  bytes: Uint8Array,
  replyTo: string | null,
): Promise<Message> {
  const contentType = sniffImageType(bytes);
  if (!contentType) throw new HttpError(415, "invalid_image", "Fotka musí byť JPEG, PNG alebo WebP.");
  return db.asUser(userId, async (tx) => {
    const id = await insertMessage(tx, userId, convId, { kind: "image", body: null, replyTo });
    await tx.query("INSERT INTO message_images (message_id, content_type, data) VALUES ($1::uuid, $2, $3)", [
      id,
      contentType,
      Buffer.from(bytes),
    ]);
    return oneMessage(tx, userId, id);
  });
}

/** Fotka zo správy (len pre členov, ktorí správu vidia). */
export function image(db: Db, userId: string, messageId: string) {
  return db.asUser(userId, async (tx) => {
    const [row] = await tx.query<{ content_type: string; data: Buffer }>(
      "SELECT content_type, data FROM message_images WHERE message_id = $1::uuid",
      [messageId],
    );
    if (!row) throw new HttpError(404, "photo_not_found", "Fotku sme nenašli.");
    return { contentType: row.content_type, bytes: new Uint8Array(row.data) };
  });
}

export function edit(db: Db, userId: string, messageId: string, body: string): Promise<Message> {
  return db.asUser(userId, async (tx) => {
    await guarded(() => tx.query("SELECT edit_message($1::uuid, $2)", [messageId, body]), messageNotFound);
    return oneMessage(tx, userId, messageId);
  });
}

export async function remove(db: Db, userId: string, messageId: string): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(() => tx.query("SELECT delete_message($1::uuid)", [messageId]), messageNotFound),
  );
}

export function react(db: Db, userId: string, messageId: string, emoji: string | null): Promise<Message> {
  return db.asUser(userId, async (tx) => {
    await guarded(() => tx.query("SELECT react_message($1::uuid, $2)", [messageId, emoji]), messageNotFound);
    return oneMessage(tx, userId, messageId);
  });
}

// ------------------------------------------------------ stav konverzácie

export async function markRead(db: Db, userId: string, convId: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    await requireMember(tx, convId);
    await tx.query(
      "SELECT mark_conversation_read($1::uuid, (SELECT max(sent_at) FROM messages WHERE conversation_id = $1::uuid))",
      [convId],
    );
  });
}

export async function typing(db: Db, userId: string, convId: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    await requireMember(tx, convId);
    await tx.query("SELECT set_typing($1::uuid)", [convId]);
  });
}

export async function mute(db: Db, userId: string, convId: string, muted: boolean): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(() => tx.query("SELECT set_conversation_muted($1::uuid, $2)", [convId, muted])),
  );
}

// -------------------------------------------------------------- blokovanie

export function blocks(db: Db, userId: string): Promise<Contact[]> {
  return db.asUser(userId, (tx) =>
    tx.query<Contact>(
      `SELECT p.id::text, p.display_name AS name, p.role::text AS role
       FROM user_blocks b JOIN public_profiles p ON p.id = b.blocked_id
       WHERE b.blocker_id = $1::uuid ORDER BY lower(p.display_name)`,
      [userId],
    ),
  );
}

export async function block(db: Db, userId: string, otherId: string): Promise<void> {
  if (otherId === userId) throw new HttpError(400, "invalid_user", "Seba zablokovať nejde.");
  await db.asUser(userId, async (tx) => {
    const [exists] = await tx.query("SELECT 1 FROM public_profiles WHERE id = $1::uuid", [otherId]);
    if (!exists) throw new HttpError(404, "user_not_found", "Používateľ sa nenašiel.");
    await tx.query(
      "INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING",
      [userId, otherId],
    );
  });
}

export async function unblock(db: Db, userId: string, otherId: string): Promise<void> {
  await db.asUser(userId, (tx) =>
    tx.query("DELETE FROM user_blocks WHERE blocker_id = $1::uuid AND blocked_id = $2::uuid", [userId, otherId]),
  );
}
