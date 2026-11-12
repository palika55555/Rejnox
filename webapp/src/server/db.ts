import { Client } from "pg";

/** Jeden SQL príkaz v rámci transakcie. */
export type Tx = {
  query<R = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<R[]>;
};

/**
 * Prístup k databáze. Každá práca v mene používateľa beží v transakcii,
 * v ktorej je nastavené app.user_id, takže databáza (RLS) vydá len jeho riadky.
 */
export type Db = {
  /** Transakcia bez prihláseného používateľa (registrácia, overenie tokenu). */
  transaction<T>(body: (tx: Tx) => Promise<T>): Promise<T>;
  /** Transakcia v mene používateľa. */
  asUser<T>(userId: string, body: (tx: Tx) => Promise<T>): Promise<T>;
};

export async function actAs(tx: Tx, userId: string): Promise<void> {
  await tx.query("SELECT set_config('app.user_id', $1, true)", [userId]);
}

function connectionString(): string {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("Chýba DATABASE_URL (pozri webapp/.env.example).");
  return url;
}

/**
 * Otvorí spojenie len na dobu jednej požiadavky. Na Cloudflare Workers sa
 * spojenia nesmú zdieľať medzi požiadavkami, preto tu nie je pool.
 */
export async function withDb<T>(body: (db: Db) => Promise<T>, url = connectionString()): Promise<T> {
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    const tx: Tx = {
      async query<R>(sql: string, params?: unknown[]) {
        const result = await client.query(sql, params);
        return result.rows as R[];
      },
    };
    const transaction = async <R>(fn: (tx: Tx) => Promise<R>): Promise<R> => {
      await client.query("BEGIN");
      try {
        const value = await fn(tx);
        await client.query("COMMIT");
        return value;
      } catch (error) {
        await client.query("ROLLBACK").catch(() => undefined);
        throw error;
      }
    };
    return await body({
      transaction,
      asUser: (userId, fn) =>
        transaction(async (t) => {
          await actAs(t, userId);
          return fn(t);
        }),
    });
  } finally {
    await client.end().catch(() => undefined);
  }
}
