import { HttpError } from "./errors";
import type { Body } from "./validate";

const DEFAULT_MAX_BODY = 16 * 1024;

const baseHeaders = {
  "content-type": "application/json; charset=utf-8",
  "x-content-type-options": "nosniff",
  "cache-control": "no-store",
};

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: baseHeaders });
}

export function noContent(): Response {
  return new Response(null, { status: 204, headers: { "x-content-type-options": "nosniff", "cache-control": "no-store" } });
}

export function errorResponse(error: HttpError): Response {
  return json(error.status, { error: { code: error.code, message: error.message } });
}

const tooLarge = () => new HttpError(413, "body_too_large", "Požiadavka je príliš veľká.");

/** Číta telo po kúskoch a skončí hneď, ako prekročí limit (bez načítania celého tela do pamäte). */
async function readCapped(request: Request, maxBytes: number): Promise<Uint8Array> {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw tooLarge();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

/** Načíta telo požiadavky ako JSON objekt, s limitom veľkosti. */
export async function readJsonBody(request: Request, maxBytes = DEFAULT_MAX_BODY): Promise<Body> {
  const declared = Number(request.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > maxBytes) throw tooLarge();
  const bytes = await readCapped(request, maxBytes);
  try {
    const decoded: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (typeof decoded === "object" && decoded !== null && !Array.isArray(decoded)) return decoded as Body;
  } catch {
    // Spadne na chybu nižšie.
  }
  throw new HttpError(400, "invalid_json", "Neplatné telo požiadavky.");
}

/** Token z hlavičky "Authorization: Bearer ...". */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

/**
 * IP adresa klienta (pre limit pokusov). Na Cloudflare ju vždy nastaví
 * hlavička cf-connecting-ip, ktorú klient nepodvrhne (Cloudflare ju prepíše).
 * Lokálne (next dev) žiadna proxy nie je, všetci sú "local".
 */
export function clientIp(request: Request): string {
  return request.headers.get("cf-connecting-ip")?.trim() || "local";
}
