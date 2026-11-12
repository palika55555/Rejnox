const encoder = new TextEncoder();

/** SHA-256 ako hex reťazec (odtlačok tokenu, pozývacieho kódu, kľúča limitu). */
export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Náhodný token relácie: 32 bajtov v base64url bez "=". */
export function newSessionToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

/** Rovnomerne náhodné číslo 0 ≤ n < max (bez skreslenia modulom). */
export function randomInt(max: number): number {
  const limit = Math.floor(0x1_0000_0000 / max) * max;
  const buffer = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buffer);
    if (buffer[0] < limit) return buffer[0] % max;
  }
}

export function utf8Length(value: string): number {
  return encoder.encode(value).length;
}
