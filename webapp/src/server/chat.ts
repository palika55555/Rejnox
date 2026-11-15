import type { Db, Tx } from "./db";
import { HttpError, pgCode } from "./errors";
import { requireText, type Body } from "./validate";

/** Najviac správ v jednej odpovedi. */
export const PAGE_SIZE = 50;

/** Najdlhšia správa (rovnaký limit ako v databáze). */
export const MAX_MESSAGE = 4000;

const notFound = () => new HttpError(404, "not_found", "Konverzácia sa nenašla.");
const closed = () => new HttpError(409, "chat_closed", "Spolupráca skončila, písať už nejde.");

export type ChatThread = {
  linkId: string;
  name: string;
  /** Druhá strana je tréner (pre klienta) alebo klient (pre trénera). */
  otherRole: "trainer" | "client";
  canSend: boolean;
  unread: number;
  lastMessage: { body: string; sentAt: string; mine: boolean } | null;
};

/** `sentAt` je ISO čas s mikrosekundami (presný kurzor pre ?after=). */
export type ChatMessage = { id: string; body: string; sentAt: string; mine: boolean };

export function parseMessage(body: Body): string {
  return requireText(body, "body", MAX_MESSAGE, "Správa");
}

const isoTime = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:?\d{2})$/;

/**
 * Čas z dopytu (?after=, ?before=), inak null. Ostáva textom, lebo Date
 * by orezal mikrosekundy a priebežné načítanie by vrátilo poslednú správu znova.
 */
export function parseCursor(value: string | null): string | null {
  if (!value) return null;
  if (!isoTime.test(value) || Number.isNaN(Date.parse(value))) {
    throw new HttpError(400, "invalid_cursor", "Neplatný čas.");
  }
  return value;
}

/**
 * Konverzácie prihláseného: všetky aktívne prepojenia (aj bez správ)
 * a ukončené, v ktorých nejaké správy sú. Najnovšie hore.
 */
export function threads(db: Db, userId: string): Promise<ChatThread[]> {
  return db.asUser(userId, (tx) =>
    tx.query<ChatThread>(
      `SELECT t.id::text AS "linkId",
              CASE WHEN t.trainer_id = $1::uuid THEN t.client_name ELSE p.display_name END AS name,
              CASE WHEN t.trainer_id = $1::uuid THEN 'client' ELSE 'trainer' END AS "otherRole",
              t.status = 'linked' AS "canSend",
              coalesce((SELECT count(*)::int FROM messages m
                        WHERE m.conversation_id = c.id AND m.sender_id <> $1::uuid
                          AND m.sent_at > cm.last_read_at), 0) AS unread,
              (SELECT json_build_object('body', m.body, 'sentAt', m.sent_at, 'mine', m.sender_id = $1::uuid)
               FROM messages m WHERE m.conversation_id = c.id
               ORDER BY m.sent_at DESC LIMIT 1) AS "lastMessage"
       FROM trainer_clients t
       LEFT JOIN public_profiles p ON p.id = t.trainer_id
       LEFT JOIN conversations c ON c.trainer_client_id = t.id
       LEFT JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = $1::uuid
       WHERE (t.trainer_id = $1::uuid OR t.client_user_id = $1::uuid)
         AND t.client_user_id IS NOT NULL
         AND (t.status = 'linked' OR c.id IS NOT NULL)
       ORDER BY (SELECT max(m.sent_at) FROM messages m WHERE m.conversation_id = c.id) DESC NULLS LAST,
                lower(CASE WHEN t.trainer_id = $1::uuid THEN t.client_name ELSE p.display_name END)`,
      [userId],
    ),
  );
}

/** Počet neprečítaných správ zo všetkých konverzácií. Beží v transakcii volajúceho. */
export async function unreadTotal(tx: Tx, userId: string): Promise<number> {
  const [row] = await tx.query<{ n: number }>(
    `SELECT count(*)::int AS n
     FROM conversation_members cm
     JOIN messages m ON m.conversation_id = cm.conversation_id
     WHERE cm.user_id = $1::uuid AND m.sender_id <> $1::uuid AND m.sent_at > cm.last_read_at`,
    [userId],
  );
  return row.n;
}

/** Konverzácia k prepojeniu, null ak ešte nie je (a založiť ju netreba). */
async function conversationOf(tx: Tx, linkId: string, create: boolean): Promise<string | null> {
  if (!create) {
    // Prístup k prepojeniu overí RLS (trainer_clients vidí len jeho strany).
    const [link] = await tx.query<{ conv: string | null }>(
      `SELECT c.id::text AS conv FROM trainer_clients t
       LEFT JOIN conversations c ON c.trainer_client_id = t.id
       WHERE t.id = $1::uuid AND t.client_user_id IS NOT NULL`,
      [linkId],
    );
    if (!link) throw notFound();
    return link.conv;
  }
  try {
    const [row] = await tx.query<{ id: string }>("SELECT link_conversation($1::uuid)::text AS id", [linkId]);
    return row.id;
  } catch (error) {
    if (pgCode(error) === "P0002") throw notFound();
    if (pgCode(error) === "42501") throw closed();
    throw error;
  }
}

/**
 * Správy v konverzácii, staršie hore. Bez kurzora posledných PAGE_SIZE,
 * s `after` len novšie (pre priebežné načítanie), s `before` staršie.
 * Načítanie označí konverzáciu ako prečítanú.
 */
export function messages(
  db: Db,
  userId: string,
  linkId: string,
  cursor: { after: string | null; before: string | null },
): Promise<ChatMessage[]> {
  return db.asUser(userId, async (tx) => {
    const conv = await conversationOf(tx, linkId, false);
    if (!conv) return [];
    const rows = await tx.query<ChatMessage>(
      `SELECT id::text, body, to_json(sent_at) #>> '{}' AS "sentAt", sender_id = $2::uuid AS mine
       FROM messages
       WHERE conversation_id = $1::uuid
         AND ($3::timestamptz IS NULL OR sent_at > $3::timestamptz)
         AND ($4::timestamptz IS NULL OR sent_at < $4::timestamptz)
       ORDER BY sent_at ${cursor.after ? "ASC" : "DESC"}
       LIMIT ${PAGE_SIZE}`,
      [conv, userId, cursor.after, cursor.before],
    );
    // Prečítané len po najnovšiu správu, ktorú appka práve dostala.
    const newest = cursor.after ? rows.at(-1) : cursor.before ? undefined : rows[0];
    if (newest) await tx.query("SELECT mark_conversation_read($1::uuid, $2::timestamptz)", [conv, newest.sentAt]);
    return cursor.after ? rows : rows.reverse();
  });
}

export function send(db: Db, userId: string, linkId: string, body: string): Promise<ChatMessage> {
  return db.asUser(userId, async (tx) => {
    const conv = (await conversationOf(tx, linkId, true))!;
    try {
      const [row] = await tx.query<ChatMessage>(
        `INSERT INTO messages (conversation_id, sender_id, body)
         VALUES ($1::uuid, $2::uuid, $3)
         RETURNING id::text, body, to_json(sent_at) #>> '{}' AS "sentAt", true AS mine`,
        [conv, userId, body],
      );
      return row;
    } catch (error) {
      // RLS odmietne zápis po ukončení spolupráce.
      if (pgCode(error) === "42501") throw closed();
      throw error;
    }
  });
}

export async function markRead(db: Db, userId: string, linkId: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const conv = await conversationOf(tx, linkId, false);
    if (!conv) return;
    await tx.query(
      `SELECT mark_conversation_read($1::uuid, (SELECT max(sent_at) FROM messages WHERE conversation_id = $1::uuid))`,
      [conv],
    );
  });
}
