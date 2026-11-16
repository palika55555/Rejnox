"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { currentUser } from "@/lib/session";
import { withDb } from "@/server/db";
import { HttpError } from "@/server/errors";
import * as mealPlans from "@/server/mealPlans";
import * as trainer from "@/server/trainer";
import { optionalText, requireText, requireUuid, type Body } from "@/server/validate";

export type ActionResult<T = object> = ({ ok: true } & T) | { ok: false; message: string };

async function trainerId(): Promise<string> {
  const user = await currentUser();
  if (!user || user.role !== "trainer") throw new HttpError(403, "trainers_only", "Táto časť je len pre trénerov.");
  return user.id;
}

/** Spustí akciu trénera; chyby pre používateľa vráti ako správu, ostatné nechá spadnúť. */
async function attempt<T extends object>(body: (me: string) => Promise<T>): Promise<ActionResult<T>> {
  try {
    const result = await body(await trainerId());
    return { ok: true, ...result };
  } catch (error) {
    if (error instanceof HttpError) return { ok: false, message: error.message };
    throw error;
  }
}

function asBody(value: unknown): Body {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpError(400, "invalid_json", "Neplatné údaje.");
  }
  return value as Body;
}

// ---------------------------------------------------------------- klienti

export type AddClientState = { message?: string; clientId?: string } | undefined;

export async function addClient(_prev: AddClientState, form: FormData): Promise<AddClientState> {
  const result = await attempt(async (me) => {
    const body = { name: form.get("name"), note: form.get("note") || null } as Body;
    const client = await withDb((db) =>
      trainer.addClient(db, me, requireText(body, "name", 60, "Meno"), optionalText(body, "note", 500)),
    );
    return { clientId: String((client as { id: string }).id) };
  });
  if (!result.ok) return { message: result.message };
  redirect(`/trener/klienti/${result.clientId}`);
}

export async function inviteClient(clientId: string): Promise<ActionResult<{ code: string; expiresAt: string }>> {
  return attempt((me) => withDb((db) => trainer.invite(db, me, requireUuid(clientId))));
}

// ---------------------------------------------------------------- jedálničky

/** Uloží jedálniček (nový alebo existujúci), voliteľne ho hneď odošle klientovi. */
export async function saveMealPlan(
  clientId: string,
  planId: string | null,
  payload: unknown,
  sendNow: boolean,
): Promise<ActionResult<{ planId: string; sent: boolean }>> {
  const result = await attempt(async (me) => {
    const client = requireUuid(clientId);
    const input = mealPlans.parseMealPlan(asBody(payload));
    const saved = await withDb((db) =>
      planId
        ? mealPlans.update(db, me, client, requireUuid(planId), input)
        : mealPlans.create(db, me, client, input),
    );
    if (sendNow) await withDb((db) => mealPlans.send(db, me, client, saved.id));
    return { planId: saved.id, sent: sendNow };
  });
  if (result.ok) refresh();
  return result;
}

export async function sendMealPlan(clientId: string, planId: string): Promise<ActionResult> {
  const result = await attempt(async (me) => {
    await withDb((db) => mealPlans.send(db, me, requireUuid(clientId), requireUuid(planId)));
    return {};
  });
  if (result.ok) refresh();
  return result;
}

export async function deleteMealPlan(clientId: string, planId: string): Promise<ActionResult> {
  const result = await attempt(async (me) => {
    await withDb((db) => mealPlans.remove(db, me, requireUuid(clientId), requireUuid(planId)));
    return {};
  });
  if (result.ok) refresh();
  return result;
}

export async function copyMealPlan(
  clientId: string,
  planId: string,
  targetClientId: string,
): Promise<ActionResult<{ planId: string }>> {
  const result = await attempt(async (me) => {
    const copy = await withDb((db) =>
      mealPlans.copy(db, me, requireUuid(clientId), requireUuid(planId), requireUuid(targetClientId)),
    );
    return { planId: copy.id };
  });
  if (result.ok) refresh();
  return result;
}
