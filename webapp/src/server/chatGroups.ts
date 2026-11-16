import { guarded } from "./conversations";
import { sha256Hex } from "./crypto";
import type { Db } from "./db";
import { HttpError } from "./errors";
import { newInviteCode, normalizeInviteCode, requireText, type Body } from "./validate";

// Skupinový chat: zakladanie, členovia, správcovia a pozývacie kódy.
// Kto čo smie, rozhodujú funkcie v databáze (migrácia 018).

export const MAX_TITLE = 60;

const groupNotFound = () => new HttpError(404, "not_found", "Skupina sa nenašla.");
const memberNotFound = () => new HttpError(404, "member_not_found", "Člen sa nenašiel.");

export function parseTitle(body: Body): string {
  return requireText(body, "title", MAX_TITLE, "Názov skupiny").replace(/\s+/g, " ");
}

export function parseRole(body: Body): "admin" | "member" {
  if (body.role !== "admin" && body.role !== "member") {
    throw new HttpError(400, "invalid_role", "Rola je admin alebo member.");
  }
  return body.role;
}

/** Odtlačok kódu skupiny; predpona ho oddeľuje od kódov pozvánok trénera. */
const codeHash = (code: string) => sha256Hex(`group|${normalizeInviteCode(code)}`);

export function create(db: Db, userId: string, title: string, members: string[]): Promise<{ id: string }> {
  return db.asUser(userId, async (tx) => {
    const [row] = await guarded(() =>
      tx.query<{ id: string }>("SELECT create_group($1, $2::uuid[])::text AS id", [title, members]),
    );
    return row;
  });
}

export async function addMembers(db: Db, userId: string, convId: string, members: string[]): Promise<number> {
  return db.asUser(userId, async (tx) => {
    const [row] = await guarded(
      () => tx.query<{ n: number }>("SELECT add_group_members($1::uuid, $2::uuid[]) AS n", [convId, members]),
      groupNotFound,
    );
    return row.n;
  });
}

/** Odobratie člena správcom, alebo odchod zo skupiny (memberId = ja). */
export async function removeMember(db: Db, userId: string, convId: string, memberId: string): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(
      () => tx.query("SELECT remove_group_member($1::uuid, $2::uuid)", [convId, memberId]),
      memberId === userId ? groupNotFound : memberNotFound,
    ),
  );
}

export async function setRole(
  db: Db,
  userId: string,
  convId: string,
  memberId: string,
  role: "admin" | "member",
): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(() => tx.query("SELECT set_group_role($1::uuid, $2::uuid, $3)", [convId, memberId, role]), memberNotFound),
  );
}

export async function rename(db: Db, userId: string, convId: string, title: string): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(() => tx.query("SELECT rename_group($1::uuid, $2)", [convId, title]), groupNotFound),
  );
}

/** Nový pozývací kód (starý prestane platiť). Kód sa ukáže len teraz. */
export function newInvite(db: Db, userId: string, convId: string): Promise<{ code: string }> {
  const code = newInviteCode();
  return db.asUser(userId, async (tx) => {
    const hash = await codeHash(code);
    await guarded(() => tx.query("SELECT set_group_invite($1::uuid, $2)", [convId, hash]), groupNotFound);
    return { code };
  });
}

export async function disableInvite(db: Db, userId: string, convId: string): Promise<void> {
  await db.asUser(userId, (tx) =>
    guarded(() => tx.query("SELECT set_group_invite($1::uuid, $2)", [convId, null]), groupNotFound),
  );
}

export async function join(db: Db, userId: string, code: string): Promise<{ id: string }> {
  const hash = await codeHash(code);
  return db.asUser(userId, async (tx) => {
    const [row] = await guarded(
      () => tx.query<{ id: string }>("SELECT join_group_by_code($1)::text AS id", [hash]),
      () => new HttpError(404, "invalid_code", "Kód neplatí alebo ho správca zrušil."),
    );
    return row;
  });
}

export async function remove(db: Db, userId: string, convId: string): Promise<void> {
  await db.asUser(userId, (tx) => guarded(() => tx.query("SELECT delete_group($1::uuid)", [convId]), groupNotFound));
}
