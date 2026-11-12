"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { clearSession, saveSession, sessionToken } from "@/lib/session";
import { validateLogin, validateRegister, type RegisterInput } from "@/lib/validation";
import * as auth from "@/server/auth";
import { withDb } from "@/server/db";
import { HttpError } from "@/server/errors";
import { dbRateLimiter } from "@/server/rateLimit";

/** Stav formulára. Heslo sa späť do formulára nikdy neposiela. */
export type AuthFormState =
  | {
      message?: string;
      errors?: Partial<Record<keyof RegisterInput, string>>;
      values?: { email?: string; displayName?: string; role?: string };
    }
  | undefined;

/** IP návštevníka pre limit pokusov (na Cloudflare ju nastaví cf-connecting-ip). */
async function visitorIp(): Promise<string> {
  return (await headers()).get("cf-connecting-ip")?.trim() || "local";
}

function field(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === "string" ? value : "";
}

export async function login(_prev: AuthFormState, form: FormData): Promise<AuthFormState> {
  const values = { email: field(form, "email") };
  const input = validateLogin(form);
  if (!input.ok) return { errors: input.errors, values };

  try {
    const ip = await visitorIp();
    const result = await withDb((db) => auth.login(db, dbRateLimiter(db), ip, input.data));
    await saveSession(result.token);
  } catch (error) {
    if (error instanceof HttpError) return { message: error.message, values };
    throw error;
  }
  redirect("/prehlad?vitaj=prihlasenie");
}

export async function register(_prev: AuthFormState, form: FormData): Promise<AuthFormState> {
  const values = {
    email: field(form, "email"),
    displayName: field(form, "displayName"),
    role: field(form, "role"),
  };
  const input = validateRegister(form);
  if (!input.ok) return { errors: input.errors, values };

  try {
    const ip = await visitorIp();
    const result = await withDb((db) => auth.register(db, dbRateLimiter(db), ip, input.data));
    await saveSession(result.token);
  } catch (error) {
    if (error instanceof HttpError) {
      if (error.code === "email_taken") return { errors: { email: error.message }, values };
      return { message: error.message, values };
    }
    throw error;
  }
  redirect("/prehlad?vitaj=registracia");
}

export async function logout(): Promise<void> {
  const token = await sessionToken();
  if (token) {
    // Reláciu zrušíme aj v databáze. Ak neodpovedá, cookie aj tak zmažeme.
    await withDb((db) => auth.logout(db, token)).catch(() => undefined);
  }
  await clearSession();
  redirect("/");
}
