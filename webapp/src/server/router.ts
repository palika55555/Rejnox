import * as auth from "./auth";
import type { AuthUser } from "./auth";
import type { Db } from "./db";
import { HttpError, unauthorized, tooManyAttempts } from "./errors";
import * as gyms from "./gyms";
import { bearerToken, clientIp, errorResponse, json, noContent, readJsonBody } from "./http";
import { dbRateLimiter, limits, type Limit, type RateLimiter } from "./rateLimit";
import * as trainer from "./trainer";
import * as training from "./training";
import {
  normalizeInviteCode,
  optionalDate,
  optionalText,
  parseTime,
  requireInt,
  requireText,
  requireUuid,
  requireWeight,
  validateDisplayName,
  validateEmail,
  validateLoginPassword,
  validateNewPassword,
  validateRole,
} from "./validate";

type Method = "GET" | "POST" | "PUT" | "DELETE";

type Ctx = {
  request: Request;
  params: Record<string, string>;
  db: Db;
  limiter: RateLimiter;
  ip: string;
  /** Prihlásený používateľ, inak 401. */
  user(): Promise<AuthUser>;
};

type Route = { method: Method; pattern: string; handler: (ctx: Ctx) => Promise<Response> };

const trainersOnly = () => new HttpError(403, "trainers_only", "Táto časť je len pre trénerov.");

async function trainerUser(ctx: Ctx): Promise<AuthUser> {
  const me = await ctx.user();
  if (me.role !== "trainer") throw trainersOnly();
  return me;
}

const id = (ctx: Ctx, name = "id") => requireUuid(ctx.params[name]);

const slowDown = () => new HttpError(429, "too_many_requests", "Priveľa požiadaviek. Skús to o chvíľu.");

/** Prihlásený používateľ, ktorý ešte nevyčerpal limit pre fitká. */
async function gymUser(ctx: Ctx, limit: Limit): Promise<string> {
  const me = await ctx.user();
  if (!(await ctx.limiter.tryAcquire(limit, me.id))) throw slowDown();
  return me.id;
}

const routes: Route[] = [
  // ------------------------------------------------------------ účet
  {
    method: "POST",
    pattern: "/auth/register",
    async handler({ request, db, limiter, ip }) {
      const body = await readJsonBody(request);
      const result = await auth.register(db, limiter, ip, {
        email: validateEmail(body),
        password: validateNewPassword(body),
        displayName: validateDisplayName(body),
        role: validateRole(body),
      });
      return json(201, result);
    },
  },
  {
    method: "POST",
    pattern: "/auth/login",
    async handler({ request, db, limiter, ip }) {
      const body = await readJsonBody(request);
      const result = await auth.login(db, limiter, ip, {
        email: validateEmail(body),
        password: validateLoginPassword(body),
      });
      return json(200, result);
    },
  },
  {
    method: "POST",
    pattern: "/auth/logout",
    async handler({ request, db }) {
      const token = bearerToken(request);
      if (token) await auth.logout(db, token);
      return noContent();
    },
  },
  { method: "GET", pattern: "/me", handler: async (ctx) => json(200, await ctx.user()) },
  {
    method: "DELETE",
    pattern: "/me",
    async handler(ctx) {
      await auth.deleteAccount(ctx.db, (await ctx.user()).id);
      return noContent();
    },
  },

  // ------------------------------------------------------------ tréningy
  {
    method: "GET",
    pattern: "/exercises",
    handler: async (ctx) => json(200, { exercises: await training.exercises(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "POST",
    pattern: "/sets/sync",
    async handler(ctx) {
      const me = await ctx.user();
      const body = await readJsonBody(ctx.request, 64 * 1024);
      const { sets, rejected } = training.parseSets(body);
      return json(200, await training.syncSets(ctx.db, me.id, sets, rejected));
    },
  },

  // ------------------------------------------------------------ tréner
  {
    method: "GET",
    pattern: "/clients",
    handler: async (ctx) => json(200, { clients: await trainer.listClients(ctx.db, (await trainerUser(ctx)).id) }),
  },
  {
    method: "POST",
    pattern: "/clients",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const body = await readJsonBody(ctx.request);
      const client = await trainer.addClient(
        ctx.db,
        me.id,
        requireText(body, "name", 60, "Meno"),
        optionalText(body, "note", 500),
      );
      return json(201, client);
    },
  },
  {
    method: "GET",
    pattern: "/clients/:id",
    handler: async (ctx) => json(200, await trainer.clientDetail(ctx.db, (await trainerUser(ctx)).id, id(ctx))),
  },
  {
    method: "DELETE",
    pattern: "/clients/:id",
    async handler(ctx) {
      await trainer.deleteClient(ctx.db, (await trainerUser(ctx)).id, id(ctx));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/clients/:id/invite",
    handler: async (ctx) => json(201, await trainer.invite(ctx.db, (await trainerUser(ctx)).id, id(ctx))),
  },
  {
    method: "POST",
    pattern: "/clients/:id/end",
    async handler(ctx) {
      await trainer.endLink(ctx.db, (await trainerUser(ctx)).id, id(ctx));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/clients/:id/workouts",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const body = await readJsonBody(ctx.request, 32 * 1024);
      const raw = body.exercises;
      if (!Array.isArray(raw) || raw.length === 0 || raw.length > 30) {
        throw new HttpError(400, "invalid_exercises", "Plán musí mať 1 až 30 cvikov.");
      }
      const workout = await trainer.addWorkout(ctx.db, me.id, id(ctx), {
        title: requireText(body, "title", 120, "Názov"),
        scheduledOn: optionalDate(body, "scheduledOn"),
        exercises: raw.map(trainer.parsePlanExercise),
      });
      return json(201, workout);
    },
  },
  {
    method: "DELETE",
    pattern: "/clients/:id/workouts/:wid",
    async handler(ctx) {
      await trainer.deleteWorkout(ctx.db, (await trainerUser(ctx)).id, id(ctx), id(ctx, "wid"));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/clients/:id/sets",
    async handler(ctx) {
      const me = await trainerUser(ctx);
      const body = await readJsonBody(ctx.request);
      const performedAt = parseTime(body.performedAt);
      if (performedAt && performedAt.getTime() > Date.now() + 24 * 60 * 60 * 1000) {
        throw new HttpError(400, "invalid_time", "Neplatný čas.");
      }
      const result = await trainer.logSet(ctx.db, me.id, id(ctx), {
        id: requireUuid(body.id),
        exerciseId: requireUuid(body.exerciseId, "exerciseId"),
        reps: requireInt(body.reps, "reps", 1, 1000),
        weightKg: requireWeight(body.weightKg),
        performedAt,
      });
      return json(201, result);
    },
  },

  // ------------------------------------------------------------ klient
  {
    method: "POST",
    pattern: "/invites/accept",
    async handler(ctx) {
      const me = await ctx.user();
      if (
        !(await ctx.limiter.tryAcquire(limits.invite, me.id)) ||
        !(await ctx.limiter.tryAcquire(limits.inviteIp, ctx.ip))
      ) {
        throw tooManyAttempts();
      }
      const body = await readJsonBody(ctx.request);
      const link = await trainer.acceptInvite(ctx.db, me.id, normalizeInviteCode(body.code));
      return json(200, link);
    },
  },
  {
    method: "GET",
    pattern: "/me/trainers",
    handler: async (ctx) => json(200, { trainers: await trainer.myTrainers(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "POST",
    pattern: "/me/trainers/:id/end",
    async handler(ctx) {
      await trainer.endLink(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },
  {
    method: "GET",
    pattern: "/me/plans",
    handler: async (ctx) => json(200, { plans: await trainer.myPlans(ctx.db, (await ctx.user()).id) }),
  },

  // ------------------------------------------------------------ fitká
  {
    method: "GET",
    pattern: "/gyms",
    handler: async (ctx) => json(200, { gyms: await gyms.listGyms(ctx.db, await gymUser(ctx, limits.gymRead)) }),
  },
  {
    method: "GET",
    pattern: "/gyms/:id",
    handler: async (ctx) => json(200, await gyms.gymDetail(ctx.db, await gymUser(ctx, limits.gymRead), id(ctx))),
  },
  {
    method: "PUT",
    pattern: "/gyms/:id/review",
    async handler(ctx) {
      const userId = await gymUser(ctx, limits.gymWrite);
      const gymId = id(ctx);
      const body = await readJsonBody(ctx.request, 1024);
      const stars = requireInt(body.stars, "stars", 1, 5);
      return json(200, await gyms.rateGym(ctx.db, userId, gymId, stars));
    },
  },
  {
    method: "DELETE",
    pattern: "/gyms/:id/review",
    handler: async (ctx) => json(200, await gyms.unrateGym(ctx.db, await gymUser(ctx, limits.gymWrite), id(ctx))),
  },
];

function match(pattern: string, path: string): Record<string, string> | null {
  const want = pattern.split("/");
  const got = path.split("/");
  if (want.length !== got.length) return null;
  const params: Record<string, string> = {};
  for (let i = 0; i < want.length; i++) {
    if (want[i].startsWith(":")) {
      if (got[i] === "") return null;
      params[want[i].slice(1)] = decodeURIComponent(got[i]);
    } else if (want[i] !== got[i]) {
      return null;
    }
  }
  return params;
}

export type Connect = <T>(body: (db: Db) => Promise<T>) => Promise<T>;

export type RouterOptions = {
  /** Otvorí spojenie s databázou na jednu požiadavku. */
  connect: Connect;
  /** Pre testy: vlastné počítadlo pokusov. */
  limiter?: (db: Db) => RateLimiter;
  onError?: (error: unknown) => void;
};

/**
 * Spracuje požiadavku na API. `path` je cesta bez predpony /api
 * (napr. "/auth/login"), rovnaká, akú používal Dart server.
 */
export async function handleApi(request: Request, path: string, options: RouterOptions): Promise<Response> {
  try {
    if (request.method === "OPTIONS") return noContent();
    if (request.method === "GET" && path === "/health") return json(200, { status: "ok" });

    for (const route of routes) {
      const params = match(route.pattern, path);
      if (!params || route.method !== request.method) continue;
      return await options.connect(async (db) => {
        let cached: Promise<AuthUser> | undefined;
        const ctx: Ctx = {
          request,
          params,
          db,
          limiter: (options.limiter ?? dbRateLimiter)(db),
          ip: clientIp(request),
          user: () =>
            (cached ??= (async () => {
              const token = bearerToken(request);
              const user = token ? await auth.userForToken(db, token) : null;
              if (!user) throw unauthorized();
              return user;
            })()),
        };
        return route.handler(ctx);
      });
    }
    throw new HttpError(404, "not_found", "Nenájdené.");
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error);
    (options.onError ?? ((e) => console.error("CHYBA API:", e)))(error);
    return json(500, { error: { code: "internal", message: "Niečo sa pokazilo." } });
  }
}
