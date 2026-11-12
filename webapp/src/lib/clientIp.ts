/**
 * IP adresa návštevníka pre limit pokusov na Dart serveri.
 *
 * Ľavá časť hlavičky x-forwarded-for je od návštevníka a dá sa podvrhnúť.
 * Next.js ju nastaví zo spojenia len vtedy, keď hlavička chýba. Dôveryhodná
 * je preto len adresa, ktorú na koniec pripísala naša vlastná proxy (napr.
 * Vercel, nginx). Za N proxy je to N-tá adresa sprava.
 */
export function clientIpFrom(forwardedFor: string | null | undefined, hops: number): string | undefined {
  if (!forwardedFor || hops < 1) return undefined;
  const entries = forwardedFor
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (entries.length < hops) return undefined;
  return entries[entries.length - hops];
}

/** Počet proxy pred Next.js z WEB_PROXY_HOPS (predvolene 1). */
export function proxyHops(value: string | undefined): number {
  const hops = Number(value);
  return value !== undefined && Number.isInteger(hops) && hops >= 0 ? hops : 1;
}
