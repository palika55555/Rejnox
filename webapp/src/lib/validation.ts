/**
 * Kontrola formulárov prihlásenia a registrácie. Pravidlá sú rovnaké ako na
 * serveri (server/lib/src/auth/validators.dart), aby používateľ videl chybu
 * hneď a server ju nemusel vracať. Server ich aj tak overuje znova.
 */

export type Role = "member" | "trainer";

export type LoginInput = { email: string; password: string };
export type RegisterInput = LoginInput & { displayName: string; role: Role };

export type FieldErrors<T> = Partial<Record<keyof T, string>>;

export type Validated<T> = { ok: true; data: T } | { ok: false; errors: FieldErrors<T> };

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const encoder = new TextEncoder();

function text(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === "string" ? value : "";
}

function checkEmail(raw: string): { email: string; error?: string } {
  const email = raw.trim().toLowerCase();
  if (email.length === 0 || email.length > 254 || !emailPattern.test(email)) {
    return { email, error: "Zadaj platný e-mail." };
  }
  return { email };
}

export function validateLogin(form: FormData): Validated<LoginInput> {
  const { email, error } = checkEmail(text(form, "email"));
  const password = text(form, "password");
  const errors: FieldErrors<LoginInput> = {};
  if (error) errors.email = error;
  if (password.length === 0) errors.password = "Zadaj heslo.";
  return Object.keys(errors).length > 0 ? { ok: false, errors } : { ok: true, data: { email, password } };
}

export function validateRegister(form: FormData): Validated<RegisterInput> {
  const { email, error } = checkEmail(text(form, "email"));
  const password = text(form, "password");
  const displayName = text(form, "displayName").trim();
  const role = text(form, "role");
  const errors: FieldErrors<RegisterInput> = {};

  if (displayName.length === 0 || displayName.length > 60) {
    errors.displayName = "Zadaj meno (najviac 60 znakov).";
  }
  if (error) errors.email = error;
  // bcrypt na serveri spracuje najviac 72 bajtov.
  if (password.length < 8 || encoder.encode(password).length > 72) {
    errors.password = "Heslo musí mať 8 až 72 znakov.";
  }
  if (role !== "member" && role !== "trainer") {
    errors.role = "Vyber, ako budeš Rejnox používať.";
  }

  return Object.keys(errors).length > 0
    ? { ok: false, errors }
    : { ok: true, data: { email, password, displayName, role: role as Role } };
}
