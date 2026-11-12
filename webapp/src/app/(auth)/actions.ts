"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { ApiError, api, type AuthResult } from "@/lib/api";
import { clientIpFrom, proxyHops } from "@/lib/clientIp";
import { clearSession, saveSession, sessionToken } from "@/lib/session";
import { validateLogin, validateRegister, type RegisterInput } from "@/lib/validation";

/** Stav formulára. Heslo sa späť do formulára nikdy neposiela. */
export type AuthFormState =
  | {
      message?: string;
      errors?: Partial<Record<keyof RegisterInput, string>>;
      values?: { email?: string; displayName?: string; role?: string };
    }
  | undefined;

async function visitorIp(): Promise<string | undefined> {
  const forwarded = (await headers()).get("x-forwarded-for");
  return clientIpFrom(forwarded, proxyHops(process.env.WEB_PROXY_HOPS));
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
    const result = await api<AuthResult>("/auth/login", {
      method: "POST",
      body: input.data,
      clientIp: await visitorIp(),
    });
    await saveSession(result.token);
  } catch (error) {
    if (error instanceof ApiError) return { message: error.message, values };
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
    const result = await api<AuthResult>("/auth/register", {
      method: "POST",
      body: input.data,
      clientIp: await visitorIp(),
    });
    await saveSession(result.token);
  } catch (error) {
    if (error instanceof ApiError) {
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
    // Reláciu zrušíme aj na serveri. Ak neodpovedá, cookie aj tak zmažeme.
    await api("/auth/logout", { method: "POST", token }).catch(() => undefined);
  }
  await clearSession();
  redirect("/");
}
