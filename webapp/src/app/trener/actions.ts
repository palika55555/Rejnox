"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";
import { currentUser } from "@/lib/session";
import { withDb } from "@/server/db";
import { HttpError } from "@/server/errors";
import * as bulk from "@/server/bulkMessages";
import * as chat from "@/server/chat";
import { generateMealPlan } from "@/server/mealPlanAi";
import * as mealPlans from "@/server/mealPlans";
import { dbRateLimiter, limits } from "@/server/rateLimit";
import { requireSubscription } from "@/server/subscription";
import * as trainer from "@/server/trainer";
import { optionalText, requireInt, requireText, requireUuid, type Body } from "@/server/validate";

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

// ---------------------------------------------------------------- hromadné správy

/** Pošle tú istú správu (s {meno}) vybraným klientom do ich chatu. */
export async function sendBulkMessage(
  clientIds: string[],
  template: string,
): Promise<ActionResult<bulk.BulkResult>> {
  return attempt(async (me) => {
    const ids = bulk.parseRecipients(clientIds);
    // Kontrola textu ešte pred odoslaním komukoľvek (dĺžka po doplnení mena).
    chat.parseMessage({ body: bulk.personalize(String(template ?? ""), "Maximilián") });
    return withDb(async (db) => {
      if (!(await dbRateLimiter(db).tryAcquire(limits.bulkMessage, me))) {
        throw new HttpError(429, "too_many_requests", "Hromadných správ bolo za hodinu priveľa. Skús to neskôr.");
      }
      return bulk.sendBulk(db, me, ids, String(template).trim());
    });
  });
}

// ---------------------------------------------------------------- AI pomocník

export type AiDraftInput = {
  brief: string;
  mealsPerDay: number;
  targets: { kcal: number | null; proteinG: number | null; carbsG: number | null; fatG: number | null };
};

/** Návrh jedálnička od AI pre klienta. Nič neukladá, tréner ho upraví v editore. */
export async function draftMealPlanWithAi(
  clientId: string,
  input: AiDraftInput,
): Promise<ActionResult<{ plan: mealPlans.MealPlanInput }>> {
  return attempt(async (me) => {
    const id = requireUuid(clientId);
    const body = asBody(input);
    const brief = optionalText(body, "brief", 1500) ?? "";
    const mealsPerDay = requireInt(body.mealsPerDay, "mealsPerDay", 2, 7);
    // Ciele prejdú rovnakou kontrolou ako pri ukladaní jedálnička.
    const { targets } = mealPlans.parseMealPlan({ title: "x", targets: body.targets });

    const client = await withDb(async (db) => {
      // AI stojí peniaze: najprv predplatné, až potom limity a samotné volanie modelu.
      await requireSubscription(db, me);
      const limiter = dbRateLimiter(db);
      if (!(await limiter.tryAcquire(limits.aiMealPlan, me)) || !(await limiter.tryAcquire(limits.aiMealPlanDay, me))) {
        throw new HttpError(429, "too_many_requests", "AI pomocníka si dnes použil už veľakrát. Skús to neskôr.");
      }
      return (await trainer.clientDetail(db, me, id)) as unknown as { name: string; note: string | null };
    });
    const plan = await generateMealPlan({ clientName: client.name, clientNote: client.note, brief, mealsPerDay, targets });
    return { plan };
  });
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
