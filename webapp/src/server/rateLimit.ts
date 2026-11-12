import { sha256Hex } from "./crypto";
import type { Db } from "./db";

export type Limit = { name: string; max: number; windowSeconds: number };

/** Rovnaké limity, aké mal Dart server. */
export const limits = {
  login: { name: "login", max: 10, windowSeconds: 5 * 60 },
  // Limit na samotný e-mail platí bez ohľadu na IP, takže ho neobíde ani
  // útočník, ktorý strieda adresy.
  loginEmail: { name: "login-email", max: 30, windowSeconds: 15 * 60 },
  // Jedna IP skúšajúca veľa rôznych e-mailov (password spraying). Pri úspechu sa nenuluje.
  loginIp: { name: "login-ip", max: 50, windowSeconds: 15 * 60 },
  register: { name: "register", max: 20, windowSeconds: 60 * 60 },
  // Hádanie pozývacích kódov: na účet aj na IP, pri úspechu sa nenuluje
  // (inak by si útočník počítadlo vynuloval vlastnou platnou pozvánkou).
  invite: { name: "invite", max: 10, windowSeconds: 60 * 60 },
  inviteIp: { name: "invite-ip", max: 30, windowSeconds: 60 * 60 },
  // Fitká: zoznam vracia až 5000 riadkov a hodnotenia by sa dali "klikať" v slučke.
  gymRead: { name: "gym-read", max: 60, windowSeconds: 60 },
  gymWrite: { name: "gym-write", max: 30, windowSeconds: 60 },
} satisfies Record<string, Limit>;

/** Počítadlo pokusov v databáze (spoločné pre všetky inštancie Workera). */
export type RateLimiter = {
  tryAcquire(limit: Limit, key: string): Promise<boolean>;
  reset(limit: Limit, key: string): Promise<void>;
};

const storedKey = (limit: Limit, key: string) => sha256Hex(`${limit.name}|${key}`);

export function dbRateLimiter(db: Db): RateLimiter {
  return {
    async tryAcquire(limit, key) {
      const hashed = await storedKey(limit, key);
      return db.transaction(async (tx) => {
        const [row] = await tx.query<{ ok: boolean }>("SELECT rate_limit_hit($1, $2, $3) AS ok", [
          hashed,
          limit.max,
          limit.windowSeconds,
        ]);
        return row.ok;
      });
    },
    async reset(limit, key) {
      const hashed = await storedKey(limit, key);
      await db.transaction((tx) => tx.query("SELECT rate_limit_reset($1)", [hashed]));
    },
  };
}
