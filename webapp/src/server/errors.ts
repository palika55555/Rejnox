/** Chyba, ktorá sa má vrátiť klientovi ako JSON s daným HTTP kódom. */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    /** Strojovo čitateľný kód (napr. "invalid_credentials"). */
    readonly code: string,
    /** Správa pre používateľa. */
    message: string,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export const unauthorized = () => new HttpError(401, "unauthorized", "Prihlás sa, prosím.");

export const tooManyAttempts = () =>
  new HttpError(429, "too_many_attempts", "Priveľa pokusov. Skús to o chvíľu.");

/** Kód chyby z PostgreSQL (napr. 23505 = porušená unikátnosť). */
export function pgCode(error: unknown): string | undefined {
  return typeof error === "object" && error !== null && "code" in error
    ? String((error as { code: unknown }).code)
    : undefined;
}
