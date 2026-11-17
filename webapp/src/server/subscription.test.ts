import { describe, expect, it } from "vitest";
import type { Db } from "./db";
import { HttpError } from "./errors";
import { hasActiveSubscription, requireSubscription } from "./subscription";

/** Podvrhnutá databáza: funkcia has_active_subscription() vráti zadanú hodnotu. */
const dbReturning = (rows: { ok: boolean }[]) => {
  const seen: { userId: string; sql: string }[] = [];
  const db = {
    transaction: async () => {
      throw new Error("nepoužité");
    },
    asUser: async (userId: string, body: (tx: unknown) => Promise<unknown>) =>
      body({
        query: async (sql: string) => {
          seen.push({ userId, sql });
          return rows;
        },
      }),
  } as unknown as Db;
  return { db, seen };
};

describe("predplatné", () => {
  it("platné predplatné prejde a pýta sa v mene daného používateľa", async () => {
    const { db, seen } = dbReturning([{ ok: true }]);
    await expect(requireSubscription(db, "u1")).resolves.toBeUndefined();
    expect(seen).toEqual([{ userId: "u1", sql: "SELECT has_active_subscription() AS ok" }]);
  });

  it("bez predplatného vráti 402 subscription_required", async () => {
    const { db } = dbReturning([{ ok: false }]);
    const error = await requireSubscription(db, "u1").catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpError);
    expect(error).toMatchObject({ status: 402, code: "subscription_required" });
  });

  it("prázdna alebo nezmyselná odpoveď databázy = žiadne predplatné", async () => {
    expect(await hasActiveSubscription(dbReturning([]).db, "u1")).toBe(false);
    expect(await hasActiveSubscription(dbReturning([{ ok: "áno" as unknown as boolean }]).db, "u1")).toBe(false);
  });
});
