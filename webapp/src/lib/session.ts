import "server-only";

import { cookies } from "next/headers";
import { cache } from "react";
import { SESSION_TTL_SECONDS, userForToken, type AuthUser } from "@/server/auth";
import { withDb } from "@/server/db";

export type User = AuthUser;

/** Názov cookie s tokenom relácie. Používa ho aj src/proxy.ts. */
export const SESSION_COOKIE = "rejnox_session";

export async function saveSession(token: string): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_TTL_SECONDS,
  });
}

export async function sessionToken(): Promise<string | undefined> {
  return (await cookies()).get(SESSION_COOKIE)?.value;
}

export async function clearSession(): Promise<void> {
  (await cookies()).delete(SESSION_COOKIE);
}

/**
 * Prihlásený používateľ podľa databázy, alebo null. Relácie sú spoločné
 * s mobilnou appkou, takže odhlásenie v mobile alebo zmazanie účtu platí aj tu.
 */
export const currentUser = cache(async (): Promise<User | null> => {
  const token = await sessionToken();
  if (!token) return null;
  return withDb((db) => userForToken(db, token));
});
