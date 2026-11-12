import bcrypt from "bcryptjs";
import { newSessionToken, sha256Hex } from "./crypto";
import { actAs, type Db, type Tx } from "./db";
import { HttpError, pgCode, tooManyAttempts } from "./errors";
import { limits, type RateLimiter } from "./rateLimit";
import type { Role } from "./validate";

export type AuthUser = { id: string; email: string; displayName: string; role: Role };
export type AuthResult = { token: string; user: AuthUser };

/** Platnosť relácie (rovnaká ako cookie na webe). */
export const SESSION_TTL_SECONDS = 30 * 24 * 60 * 60;
const BCRYPT_ROUNDS = 10;

const invalidCredentials = () => new HttpError(401, "invalid_credentials", "Nesprávny e-mail alebo heslo.");

/**
 * Hash, proti ktorému sa overuje heslo neexistujúceho účtu, aby prihlásenie
 * trvalo rovnako dlho, či účet existuje alebo nie.
 */
let dummyHash: Promise<string> | undefined;
const getDummyHash = () => (dummyHash ??= bcrypt.hash("rejnox-dummy-password", BCRYPT_ROUNDS));

const tokenHash = (token: string) => sha256Hex(token);

async function createSession(tx: Tx, userId: string): Promise<string> {
  const token = newSessionToken();
  await tx.query(
    `INSERT INTO sessions (token_hash, user_id, expires_at)
     VALUES ($1, $2::uuid, now() + make_interval(secs => $3))`,
    [await tokenHash(token), userId, SESSION_TTL_SECONDS],
  );
  return token;
}

async function loadUser(tx: Tx, id: string): Promise<AuthUser | null> {
  const [row] = await tx.query<{ email: string; display_name: string; role: Role }>(
    "SELECT email::text, display_name, role::text FROM users WHERE id = $1::uuid",
    [id],
  );
  return row ? { id, email: row.email, displayName: row.display_name, role: row.role } : null;
}

async function sessionUserId(tx: Tx, token: string): Promise<string | null> {
  const [row] = await tx.query<{ id: string | null }>("SELECT auth_session_user($1)::text AS id", [
    await tokenHash(token),
  ]);
  return row?.id ?? null;
}

export async function register(
  db: Db,
  limiter: RateLimiter,
  ip: string,
  input: { email: string; password: string; displayName: string; role: Role },
): Promise<AuthResult> {
  if (!(await limiter.tryAcquire(limits.register, ip))) throw tooManyAttempts();
  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
  try {
    return await db.transaction(async (tx) => {
      const [{ id }] = await tx.query<{ id: string }>("SELECT gen_random_uuid()::text AS id");
      await actAs(tx, id);
      await tx.query(
        `INSERT INTO users (id, email, password_hash, display_name, role)
         VALUES ($1::uuid, $2::citext, $3, $4, $5::user_role)`,
        [id, input.email, passwordHash, input.displayName, input.role],
      );
      const token = await createSession(tx, id);
      return { token, user: { id, email: input.email, displayName: input.displayName, role: input.role } };
    });
  } catch (error) {
    if (pgCode(error) === "23505") throw new HttpError(409, "email_taken", "Účet s týmto e-mailom už existuje.");
    throw error;
  }
}

export async function login(
  db: Db,
  limiter: RateLimiter,
  ip: string,
  input: { email: string; password: string },
): Promise<AuthResult> {
  const key = `${ip}|${input.email}`;
  if (!(await limiter.tryAcquire(limits.login, key)) || !(await limiter.tryAcquire(limits.loginEmail, input.email))) {
    throw tooManyAttempts();
  }

  const [found] = await db.transaction((tx) =>
    tx.query<{ id: string; password_hash: string }>(
      "SELECT id::text, password_hash FROM auth_find_user($1::citext)",
      [input.email],
    ),
  );
  const matches = await bcrypt.compare(input.password, found?.password_hash ?? (await getDummyHash()));
  if (!found || !matches) throw invalidCredentials();

  const result = await db.asUser(found.id, async (tx) => {
    const user = await loadUser(tx, found.id);
    if (!user) throw invalidCredentials();
    return { token: await createSession(tx, found.id), user };
  });
  await limiter.reset(limits.login, key);
  await limiter.reset(limits.loginEmail, input.email);
  return result;
}

/** Používateľ, ktorému patrí platný token, inak null. */
export function userForToken(db: Db, token: string): Promise<AuthUser | null> {
  return db.transaction(async (tx) => {
    const id = await sessionUserId(tx, token);
    if (!id) return null;
    await actAs(tx, id);
    return loadUser(tx, id);
  });
}

export function logout(db: Db, token: string): Promise<void> {
  return db.transaction(async (tx) => {
    const id = await sessionUserId(tx, token);
    if (!id) return;
    await actAs(tx, id);
    await tx.query("DELETE FROM sessions WHERE token_hash = $1", [await tokenHash(token)]);
  });
}

/** Zmaže účet aj všetky jeho údaje. */
export async function deleteAccount(db: Db, userId: string): Promise<void> {
  await db.asUser(userId, (tx) => tx.query("DELETE FROM users WHERE id = $1::uuid", [userId]));
}
