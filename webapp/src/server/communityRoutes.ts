import type { AuthUser } from "./auth";
import * as meet from "./communityMeet";
import * as posts from "./communityPosts";
import { HttpError } from "./errors";
import { json, noContent, readJsonBody } from "./http";
import { limits, type Limit } from "./rateLimit";
import type { Ctx, Route } from "./router";
import { optionalDate, optionalText, parseTime, requireInt, requireText, requireUuid, type Body } from "./validate";

// API komunity: /community/posts, /buddies, /events, /challenges, /leaderboard.

const id = (ctx: Ctx) => requireUuid(ctx.params.id);

const slowDown = () => new HttpError(429, "too_many_requests", "Priveľa požiadaviek. Skús to o chvíľu.");

async function limited(ctx: Ctx, limit: Limit): Promise<AuthUser> {
  const me = await ctx.user();
  if (!(await ctx.limiter.tryAcquire(limit, me.id))) throw slowDown();
  return me;
}

const body = (ctx: Ctx, max = 4 * 1024) => readJsonBody(ctx.request, max);

/** Najviac rok dopredu, nie v minulosti (s rezervou na hodiny v telefóne). */
export function requireFutureTime(body: Body, field: string, now = Date.now()): Date {
  const time = parseTime(body[field]);
  if (!time) throw new HttpError(400, `invalid_${field}`, "Neplatný čas.");
  if (time.getTime() < now - 15 * 60_000) throw new HttpError(400, `invalid_${field}`, "Čas je v minulosti.");
  if (time.getTime() > now + 366 * 86_400_000) throw new HttpError(400, `invalid_${field}`, "Najviac rok dopredu.");
  return time;
}

function requireDate(body: Body, field: string): string {
  const date = optionalDate(body, field);
  if (!date) throw new HttpError(400, `invalid_${field}`, "Chýba dátum.");
  return date;
}

export const parseBuddy = (b: Body): meet.BuddyDraft => ({
  startsAt: requireFutureTime(b, "startsAt"),
  place: requireText(b, "place", 120, "Miesto"),
  focus: optionalText(b, "focus", 60),
  note: optionalText(b, "note", 300),
});

export const parseEvent = (b: Body): meet.EventDraft => ({
  title: requireText(b, "title", 80, "Názov"),
  place: requireText(b, "place", 120, "Miesto"),
  description: optionalText(b, "description", 500),
  startsAt: requireFutureTime(b, "startsAt"),
});

export const parseChallenge = (b: Body): meet.ChallengeDraft => ({
  title: requireText(b, "title", 80, "Názov"),
  description: optionalText(b, "description", 500),
  goalDays: requireInt(b.goalDays, "goalDays", 1, 366),
  startsOn: requireDate(b, "startsOn"),
  endsOn: requireDate(b, "endsOn"),
});

function requireBool(b: Body, field: string): boolean {
  const value = b[field];
  if (typeof value !== "boolean") throw new HttpError(400, `invalid_${field}`, `Chýba pole "${field}".`);
  return value;
}

/** PUT = pridať sa / lajk, DELETE = odísť / zrušiť lajk. */
function toggle(
  pattern: string,
  action: (ctx: Ctx, me: AuthUser, on: boolean) => Promise<unknown>,
): Route[] {
  return (["PUT", "DELETE"] as const).map((method) => ({
    method,
    pattern,
    async handler(ctx: Ctx) {
      const me = await limited(ctx, limits.communityWrite);
      return json(200, await action(ctx, me, method === "PUT"));
    },
  }));
}

export const communityRoutes: Route[] = [
  // --------------------------------------------------------- príspevky
  {
    method: "GET",
    pattern: "/community/posts",
    async handler(ctx) {
      const me = await ctx.user();
      const before = parseTime(new URL(ctx.request.url).searchParams.get("before"));
      return json(200, { posts: await posts.feed(ctx.db, me.id, before) });
    },
  },
  {
    method: "POST",
    pattern: "/community/posts",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityCreate);
      const text = requireText(await body(ctx), "body", 1000, "Príspevok");
      return json(201, await posts.createPost(ctx.db, me.id, text));
    },
  },
  {
    method: "DELETE",
    pattern: "/community/posts/:id",
    async handler(ctx) {
      await posts.deletePost(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },
  ...toggle("/community/posts/:id/like", (ctx, me, on) => posts.setLike(ctx.db, me.id, id(ctx), on)),
  {
    method: "GET",
    pattern: "/community/posts/:id/comments",
    handler: async (ctx) => json(200, { comments: await posts.comments(ctx.db, (await ctx.user()).id, id(ctx)) }),
  },
  {
    method: "POST",
    pattern: "/community/posts/:id/comments",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityWrite);
      const text = requireText(await body(ctx), "body", 500, "Komentár");
      return json(201, await posts.addComment(ctx.db, me.id, id(ctx), text));
    },
  },
  {
    method: "DELETE",
    pattern: "/community/comments/:id",
    async handler(ctx) {
      await posts.deleteComment(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },

  // ----------------------------------------------------------- parťáci
  {
    method: "GET",
    pattern: "/community/buddies",
    handler: async (ctx) => json(200, { buddies: await meet.buddies(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "POST",
    pattern: "/community/buddies",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityCreate);
      return json(201, await meet.createBuddy(ctx.db, me.id, parseBuddy(await body(ctx))));
    },
  },
  {
    method: "DELETE",
    pattern: "/community/buddies/:id",
    async handler(ctx) {
      await meet.deleteBuddy(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },
  ...toggle("/community/buddies/:id/join", (ctx, me, on) => meet.joinBuddy(ctx.db, me.id, id(ctx), on)),

  // ----------------------------------------------------------- udalosti
  {
    method: "GET",
    pattern: "/community/events",
    handler: async (ctx) => json(200, { events: await meet.events(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "POST",
    pattern: "/community/events",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityCreate);
      return json(201, await meet.createEvent(ctx.db, me.id, parseEvent(await body(ctx))));
    },
  },
  {
    method: "DELETE",
    pattern: "/community/events/:id",
    async handler(ctx) {
      await meet.deleteEvent(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },
  ...toggle("/community/events/:id/join", (ctx, me, on) => meet.joinEvent(ctx.db, me.id, id(ctx), on)),

  // -------------------------------------------------------------- výzvy
  {
    method: "GET",
    pattern: "/community/challenges",
    handler: async (ctx) => json(200, { challenges: await meet.challenges(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "POST",
    pattern: "/community/challenges",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityCreate);
      return json(201, await meet.createChallenge(ctx.db, me.id, parseChallenge(await body(ctx))));
    },
  },
  {
    method: "DELETE",
    pattern: "/community/challenges/:id",
    async handler(ctx) {
      await meet.deleteChallenge(ctx.db, (await ctx.user()).id, id(ctx));
      return noContent();
    },
  },
  ...toggle("/community/challenges/:id/join", (ctx, me, on) => meet.joinChallenge(ctx.db, me.id, id(ctx), on)),

  // ----------------------------------------------------------- rebríček
  {
    method: "GET",
    pattern: "/community/leaderboard",
    handler: async (ctx) => json(200, await meet.leaderboard(ctx.db, (await ctx.user()).id)),
  },
  {
    method: "PUT",
    pattern: "/community/leaderboard/opt-in",
    async handler(ctx) {
      const me = await limited(ctx, limits.communityWrite);
      const enabled = requireBool(await body(ctx, 256), "enabled");
      return json(200, await meet.setLeaderboardOptIn(ctx.db, me.id, enabled));
    },
  },
];
