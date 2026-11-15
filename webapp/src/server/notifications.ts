import { unreadTotal } from "./chat";
import type { Db } from "./db";
import { HttpError } from "./errors";

/** Koľko posledných upozornení appka dostane. */
const LIMIT = 50;

export type AppNotification = {
  id: string;
  kind: string;
  title: string;
  body: string | null;
  linkId: string | null;
  createdAt: Date;
  read: boolean;
};

export type NotificationFeed = {
  notifications: AppNotification[];
  /** Neprečítané upozornenia. */
  unread: number;
  /** Neprečítané správy v chate (odznak pri Správach). */
  unreadMessages: number;
};

/** Posledné upozornenia a počty neprečítaných. Appka to načítava priebežne. */
export function feed(db: Db, userId: string): Promise<NotificationFeed> {
  return db.asUser(userId, async (tx) => {
    const notifications = await tx.query<AppNotification>(
      `SELECT id::text, kind, title, body, link_id::text AS "linkId",
              created_at AS "createdAt", read_at IS NOT NULL AS read
       FROM notifications WHERE user_id = $1::uuid
       ORDER BY created_at DESC LIMIT ${LIMIT}`,
      [userId],
    );
    const [{ n }] = await tx.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM notifications WHERE user_id = $1::uuid AND read_at IS NULL",
      [userId],
    );
    return { notifications, unread: n, unreadMessages: await unreadTotal(tx, userId) };
  });
}

/** Označí jedno upozornenie (alebo všetky, keď [id] chýba) ako prečítané. */
export async function markRead(db: Db, userId: string, id: string | null): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const rows = await tx.query(
      `UPDATE notifications SET read_at = now()
       WHERE user_id = $1::uuid AND read_at IS NULL AND ($2::uuid IS NULL OR id = $2::uuid)
       RETURNING id`,
      [userId, id],
    );
    if (id && rows.length === 0) {
      const exists = await tx.query("SELECT 1 FROM notifications WHERE id = $1::uuid", [id]);
      if (exists.length === 0) throw new HttpError(404, "not_found", "Upozornenie sa nenašlo.");
    }
  });
}

export async function remove(db: Db, userId: string, id: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM notifications WHERE id = $1::uuid AND user_id = $2::uuid RETURNING id", [
      id,
      userId,
    ]);
    if (rows.length === 0) throw new HttpError(404, "not_found", "Upozornenie sa nenašlo.");
  });
}
