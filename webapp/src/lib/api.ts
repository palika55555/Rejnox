import "server-only";

import type { Role } from "./validation";

/** Používateľ tak, ako ho vracia Dart server (GET /me). */
export type User = {
  id: string;
  email: string;
  displayName: string;
  role: Role;
};

export type AuthResult = { token: string; user: User };

/** Chyba z API so slovenskou správou pre používateľa. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

type Options = {
  method?: "GET" | "POST" | "DELETE";
  body?: unknown;
  token?: string;
  /** IP návštevníka, aby server počítal limit pokusov pre každého zvlášť. */
  clientIp?: string;
};

function baseUrl(): string {
  const url = process.env.REJNOX_API_URL;
  if (!url) throw new Error("Chýba REJNOX_API_URL (pozri webapp/.env.example).");
  return url.replace(/\/+$/, "");
}

/**
 * Volá spoločný Dart API server. Beží len na serveri Next.js, takže token
 * ani adresa API sa nedostanú do prehliadača.
 */
export async function api<T>(path: string, { method = "GET", body, token, clientIp }: Options = {}): Promise<T> {
  const headers: Record<string, string> = {};
  if (body !== undefined) headers["content-type"] = "application/json";
  if (token) headers.authorization = `Bearer ${token}`;
  if (clientIp) headers["x-forwarded-for"] = clientIp;

  let response: Response;
  try {
    response = await fetch(`${baseUrl()}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      cache: "no-store",
    });
  } catch {
    throw new ApiError(503, "unreachable", "Server Rejnox teraz neodpovedá. Skús to o chvíľu.");
  }

  if (response.status === 204) return undefined as T;

  const data: unknown = await response.json().catch(() => null);
  if (!response.ok) {
    const error = (data as { error?: { code?: string; message?: string } } | null)?.error;
    throw new ApiError(response.status, error?.code ?? "unknown", error?.message ?? "Niečo sa pokazilo. Skús to znova.");
  }
  return data as T;
}
