import "server-only";

import { cookies } from "next/headers";
import { cache } from "react";
import { ApiError, api, type User } from "./api";

/** Názov cookie s tokenom relácie. Používa ho aj src/proxy.ts. */
export const SESSION_COOKIE = "rejnox_session";

/** Rovnaká platnosť ako relácia na serveri (AuthService.sessionTtl). */
const MAX_AGE_SECONDS = 30 * 24 * 60 * 60;

export async function saveSession(token: string): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: MAX_AGE_SECONDS,
  });
}

export async function sessionToken(): Promise<string | undefined> {
  return (await cookies()).get(SESSION_COOKIE)?.value;
}

export async function clearSession(): Promise<void> {
  (await cookies()).delete(SESSION_COOKIE);
}

/**
 * Prihlásený používateľ podľa servera, alebo null. Platnosť tokenu overuje
 * Dart server, takže odhlásenie v mobile alebo zmazanie účtu platí aj tu.
 */
export const currentUser = cache(async (): Promise<User | null> => {
  const token = await sessionToken();
  if (!token) return null;
  try {
    return await api<User>("/me", { token });
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) return null;
    throw error;
  }
});
