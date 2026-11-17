import type { Db } from "./db";
import { HttpError } from "./errors";

/** Má používateľ platné predplatné? Zdroj pravdy je databáza (funkcia has_active_subscription). */
export async function hasActiveSubscription(db: Db, userId: string): Promise<boolean> {
  const rows = await db.asUser(userId, (tx) => tx.query<{ ok: boolean }>("SELECT has_active_subscription() AS ok"));
  return rows[0]?.ok === true;
}

/** AI funkcie stoja peniaze: bez platného predplatného ich nespustíme (HTTP 402). */
export async function requireSubscription(db: Db, userId: string): Promise<void> {
  if (!(await hasActiveSubscription(db, userId))) {
    throw new HttpError(402, "subscription_required", "AI pomocník je dostupný len s aktívnym predplatným Rejnox.");
  }
}
