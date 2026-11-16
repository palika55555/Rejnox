import type { AuthUser } from "./auth";
import * as clientProgress from "./clientProgress";
import { HttpError } from "./errors";
import { json, noContent, readJsonBody } from "./http";
import * as mealPlans from "./mealPlans";
import type { Ctx, Route } from "./router";
import { optionalDate, requireUuid } from "./validate";

// API jedálničkov: tréner ich zostavuje a posiela (/clients/:id/meal-plans),
// klient ich vidí a odškrtáva zjedené jedlá (/me/meal-plans, /me/meal-items).

const id = (ctx: Ctx, name = "id") => requireUuid(ctx.params[name]);

/** Telo jedálnička: až 120 jedál s textami. */
const PLAN_BODY_MAX = 96 * 1024;

async function trainerUser(ctx: Ctx): Promise<AuthUser> {
  const me = await ctx.user();
  if (me.role !== "trainer") throw new HttpError(403, "trainers_only", "Táto časť je len pre trénerov.");
  return me;
}

function checkDay(ctx: Ctx): string {
  const day = optionalDate({ day: ctx.params.day }, "day");
  if (!day) throw new HttpError(400, "invalid_day", "Neplatný dátum.");
  return day;
}

export const mealPlanRoutes: Route[] = [
  // ------------------------------------------------------------ tréner
  {
    method: "GET",
    pattern: "/clients/:id/meal-plans",
    handler: async (ctx) =>
      json(200, { mealPlans: await mealPlans.listForClient(ctx.db, (await trainerUser(ctx)).id, id(ctx)) }),
  },
  {
    method: "POST",
    pattern: "/clients/:id/meal-plans",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const input = mealPlans.parseMealPlan(await readJsonBody(ctx.request, PLAN_BODY_MAX));
      return json(201, await mealPlans.create(ctx.db, me.id, id(ctx), input));
    },
  },
  {
    method: "GET",
    pattern: "/clients/:id/meal-plans/:pid",
    handler: async (ctx) =>
      json(200, await mealPlans.getForTrainer(ctx.db, (await trainerUser(ctx)).id, id(ctx), id(ctx, "pid"))),
  },
  {
    method: "PUT",
    pattern: "/clients/:id/meal-plans/:pid",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const input = mealPlans.parseMealPlan(await readJsonBody(ctx.request, PLAN_BODY_MAX));
      return json(200, await mealPlans.update(ctx.db, me.id, id(ctx), id(ctx, "pid"), input));
    },
  },
  {
    method: "DELETE",
    pattern: "/clients/:id/meal-plans/:pid",
    async handler(ctx) {
      await mealPlans.remove(ctx.db, (await trainerUser(ctx)).id, id(ctx), id(ctx, "pid"));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/clients/:id/meal-plans/:pid/send",
    handler: async (ctx) =>
      json(200, await mealPlans.send(ctx.db, (await trainerUser(ctx)).id, id(ctx), id(ctx, "pid"))),
  },
  {
    method: "POST",
    pattern: "/clients/:id/meal-plans/:pid/copy",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const body = await readJsonBody(ctx.request, 1024);
      const target = requireUuid(body.clientId, "clientId");
      return json(201, await mealPlans.copy(ctx.db, me.id, id(ctx), id(ctx, "pid"), target));
    },
  },
  {
    method: "GET",
    pattern: "/clients/:id/progress",
    handler: async (ctx) =>
      json(200, await clientProgress.clientProgress(ctx.db, (await trainerUser(ctx)).id, id(ctx))),
  },

  // ------------------------------------------------------------ klient
  {
    method: "GET",
    pattern: "/me/meal-plans",
    handler: async (ctx) => json(200, { mealPlans: await mealPlans.myMealPlans(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "PUT",
    pattern: "/me/meal-items/:id/checks/:day",
    async handler(ctx) {
      await mealPlans.setChecked(ctx.db, (await ctx.user()).id, id(ctx), checkDay(ctx), true);
      return noContent();
    },
  },
  {
    method: "DELETE",
    pattern: "/me/meal-items/:id/checks/:day",
    async handler(ctx) {
      await mealPlans.setChecked(ctx.db, (await ctx.user()).id, id(ctx), checkDay(ctx), false);
      return noContent();
    },
  },
];
