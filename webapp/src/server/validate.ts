import { randomInt, utf8Length } from "./crypto";
import { HttpError } from "./errors";

/** Telo požiadavky po načítaní JSON. */
export type Body = Record<string, unknown>;

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

/** Bez 0/O, 1/I/L, aby sa kód dal ľahko prepísať. */
const codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export const roles = ["member", "trainer"] as const;
export type Role = (typeof roles)[number];

export const isUuid = (value: unknown): value is string => typeof value === "string" && uuidPattern.test(value);

function requireString(body: Body, field: string): string {
  const value = body[field];
  if (typeof value !== "string") throw new HttpError(400, `invalid_${field}`, `Chýba pole "${field}".`);
  return value;
}

// ------------------------------------------------------------------ účet

export function validateEmail(body: Body): string {
  const email = requireString(body, "email").trim().toLowerCase();
  if (email.length > 254 || !emailPattern.test(email)) {
    throw new HttpError(400, "invalid_email", "Zadaj platný e-mail.");
  }
  return email;
}

/** Heslo pri registrácii: 8 až 72 bajtov (viac bcrypt nespracuje). */
export function validateNewPassword(body: Body): string {
  const password = requireString(body, "password");
  if (password.length < 8 || utf8Length(password) > 72) {
    throw new HttpError(400, "invalid_password", "Heslo musí mať 8 až 72 znakov.");
  }
  return password;
}

/** Heslo pri prihlásení: len kontrola, že je rozumne dlhé. */
export function validateLoginPassword(body: Body): string {
  const password = requireString(body, "password");
  if (password.length === 0 || utf8Length(password) > 72) {
    throw new HttpError(401, "invalid_credentials", "Nesprávny e-mail alebo heslo.");
  }
  return password;
}

export function validateDisplayName(body: Body): string {
  const name = requireString(body, "displayName").trim();
  if (name.length === 0 || name.length > 60) {
    throw new HttpError(400, "invalid_displayName", "Meno musí mať 1 až 60 znakov.");
  }
  return name;
}

export function validateRole(body: Body): Role {
  const role = body.role ?? "member";
  if (typeof role !== "string" || !(roles as readonly string[]).includes(role)) {
    throw new HttpError(400, "invalid_role", "Neplatná rola.");
  }
  return role as Role;
}

// ---------------------------------------------------------- všeobecné polia

export function requireUuid(value: unknown, field = "id"): string {
  if (!isUuid(value)) throw new HttpError(400, `invalid_${field}`, "Neplatné ID.");
  return value;
}

export function requireText(body: Body, field: string, max: number, label = "Pole"): string {
  const value = body[field];
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length === 0 || text.length > max) {
    throw new HttpError(400, `invalid_${field}`, `${label} musí mať 1 až ${max} znakov.`);
  }
  return text;
}

export function optionalText(body: Body, field: string, max: number): string | null {
  const value = body[field];
  if (value === undefined || value === null) return null;
  const text = typeof value === "string" ? value.trim() : "";
  if (text.length > max) throw new HttpError(400, `invalid_${field}`, "Text je príliš dlhý.");
  return text.length === 0 ? null : text;
}

export function requireInt(value: unknown, field: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < min || value > max) {
    throw new HttpError(400, `invalid_${field}`, `Zadaj ${min} až ${max}.`);
  }
  return value;
}

export function requireWeight(value: unknown, field = "weightKg"): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1000) {
    throw new HttpError(400, `invalid_${field}`, "Váha musí byť 0 až 1000 kg.");
  }
  return value;
}

/** Dátum v tvare RRRR-MM-DD (vráti sa rovnaký reťazec). */
export function optionalDate(body: Body, field: string): string | null {
  const value = body[field];
  if (value === undefined || value === null) return null;
  const valid =
    typeof value === "string" &&
    datePattern.test(value) &&
    new Date(`${value}T00:00:00Z`).toISOString().startsWith(value);
  if (!valid) throw new HttpError(400, `invalid_${field}`, "Neplatný dátum.");
  return value;
}

/** Čas v ISO tvare, inak null. */
export function parseTime(value: unknown): Date | null {
  if (typeof value !== "string" || value.length === 0) return null;
  const time = new Date(value);
  return Number.isNaN(time.getTime()) ? null : time;
}

// ------------------------------------------------------- pozývacie kódy

/** Nový pozývací kód, napr. "K7QM-4XPA" (~40 bitov náhody). */
export function newInviteCode(): string {
  const chars = Array.from({ length: 8 }, () => codeAlphabet[randomInt(codeAlphabet.length)]).join("");
  return `${chars.slice(0, 4)}-${chars.slice(4)}`;
}

/** Kód tak, ako sa hashuje: veľké písmená, bez pomlčiek a medzier. */
export function normalizeInviteCode(value: unknown): string {
  const code = typeof value === "string" ? value.toUpperCase().replace(/[\s-]/g, "") : "";
  if (code.length !== 8 || [...code].some((c) => !codeAlphabet.includes(c))) {
    throw new HttpError(400, "invalid_code", "Kód má tvar XXXX-XXXX.");
  }
  return code;
}
