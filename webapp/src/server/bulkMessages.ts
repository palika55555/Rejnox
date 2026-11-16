import * as chat from "./chat";
import type { Db } from "./db";
import { HttpError } from "./errors";

/** Najviac príjemcov jednej hromadnej správy. */
export const MAX_RECIPIENTS = 100;

/** Zástupný text, ktorý sa nahradí krstným menom klienta. */
export const NAME_TOKEN = "{meno}";

export const firstName = (name: string) => name.trim().split(/\s+/)[0] ?? name;

/** Text pre jedného klienta: {meno} → krstné meno. */
export function personalize(template: string, clientName: string): string {
  return template.replaceAll(NAME_TOKEN, firstName(clientName));
}

export function parseRecipients(value: unknown): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpError(400, "invalid_recipients", "Vyber aspoň jedného klienta.");
  }
  if (value.length > MAX_RECIPIENTS) {
    throw new HttpError(400, "invalid_recipients", `Naraz sa dá poslať najviac ${MAX_RECIPIENTS} klientom.`);
  }
  const ids = [...new Set(value)];
  if (ids.some((id) => typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id))) {
    throw new HttpError(400, "invalid_recipients", "Neplatný klient.");
  }
  return ids as string[];
}

export type BulkResult = { sent: string[]; skipped: string[] };

/**
 * Pošle správu každému vybranému klientovi do jeho chatu s trénerom.
 * Klienti bez prepojenej appky (alebo s ukončenou spoluprácou) sa preskočia.
 */
export async function sendBulk(db: Db, trainerId: string, clientIds: string[], template: string): Promise<BulkResult> {
  const clients = await db.asUser(trainerId, (tx) =>
    tx.query<{ id: string; name: string; linked: boolean }>(
      `SELECT id::text, client_name AS name, status = 'linked' AND client_user_id IS NOT NULL AS linked
       FROM trainer_clients WHERE trainer_id = $1::uuid AND id = ANY($2::uuid[])`,
      [trainerId, clientIds],
    ),
  );
  const result: BulkResult = { sent: [], skipped: [] };
  for (const c of clients) {
    if (!c.linked) {
      result.skipped.push(c.name);
      continue;
    }
    const body = chat.parseMessage({ body: personalize(template, c.name) });
    await chat.send(db, trainerId, c.id, body);
    result.sent.push(c.name);
  }
  return result;
}
