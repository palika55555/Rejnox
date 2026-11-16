import type { AuthUser } from "./auth";
import * as groups from "./chatGroups";
import * as conversations from "./conversations";
import { HttpError } from "./errors";
import { image, json, noContent, readBytes, readJsonBody } from "./http";
import { limits, type Limit } from "./rateLimit";
import type { Ctx, Route } from "./router";
import { requireUuid } from "./validate";

// API chatu: /conversations (všetky druhy konverzácií), /messages, /groups, /chat.
// Staré /chats/:linkId ostáva v router.ts pre staršie verzie appky.

const id = (ctx: Ctx, name = "id") => requireUuid(ctx.params[name]);

const slowDown = () => new HttpError(429, "too_many_requests", "Priveľa požiadaviek. Skús to o chvíľu.");

/** Prihlásený používateľ s nevyčerpaným limitom. */
async function limited(ctx: Ctx, limit: Limit): Promise<AuthUser> {
  const me = await ctx.user();
  if (!(await ctx.limiter.tryAcquire(limit, me.id))) throw slowDown();
  return me;
}

const body = (ctx: Ctx, max = 4 * 1024) => readJsonBody(ctx.request, max);

export const conversationRoutes: Route[] = [
  // ------------------------------------------------------- konverzácie
  {
    method: "GET",
    pattern: "/conversations",
    handler: async (ctx) => json(200, { conversations: await conversations.list(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "GET",
    pattern: "/conversations/:id",
    handler: async (ctx) => json(200, await conversations.detail(ctx.db, (await ctx.user()).id, id(ctx))),
  },
  {
    method: "POST",
    pattern: "/conversations/link/:id",
    handler: async (ctx) => json(200, await conversations.forLink(ctx.db, (await ctx.user()).id, id(ctx))),
  },
  {
    method: "POST",
    pattern: "/conversations/direct",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const other = requireUuid((await body(ctx, 1024)).userId, "userId");
      return json(200, await conversations.direct(ctx.db, me.id, other));
    },
  },
  {
    method: "GET",
    pattern: "/conversations/:id/messages",
    async handler(ctx) {
      const me = await ctx.user();
      const cursor = conversations.parseMessageCursor(new URL(ctx.request.url));
      return json(200, await conversations.messages(ctx.db, me.id, id(ctx), cursor));
    },
  },
  {
    method: "POST",
    pattern: "/conversations/:id/messages",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatSend);
      const convId = id(ctx);
      const input = await body(ctx, 32 * 1024);
      return json(
        201,
        await conversations.send(ctx.db, me.id, convId, {
          body: conversations.parseBody(input),
          replyTo: conversations.optionalUuid(input.replyTo, "replyTo"),
        }),
      );
    },
  },
  {
    method: "POST",
    pattern: "/conversations/:id/images",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatImage);
      if (!(await ctx.limiter.tryAcquire(limits.chatImageDay, me.id))) throw slowDown();
      const convId = id(ctx);
      const replyTo = conversations.optionalUuid(new URL(ctx.request.url).searchParams.get("replyTo"), "replyTo");
      const bytes = await readBytes(ctx.request, conversations.MAX_IMAGE_BYTES);
      return json(201, await conversations.sendImage(ctx.db, me.id, convId, bytes, replyTo));
    },
  },
  {
    method: "POST",
    pattern: "/conversations/:id/read",
    async handler(ctx) {
      await conversations.markRead(ctx.db, (await limited(ctx, limits.chatPresence)).id, id(ctx));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/conversations/:id/typing",
    async handler(ctx) {
      await conversations.typing(ctx.db, (await limited(ctx, limits.chatPresence)).id, id(ctx));
      return noContent();
    },
  },
  {
    method: "PUT",
    pattern: "/conversations/:id/mute",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const convId = id(ctx);
      const muted = (await body(ctx, 256)).muted;
      if (typeof muted !== "boolean") throw new HttpError(400, "invalid_muted", "Chýba pole muted.");
      await conversations.mute(ctx.db, me.id, convId, muted);
      return noContent();
    },
  },

  // ------------------------------------------------------------- správy
  {
    method: "GET",
    pattern: "/chat-images/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatImageRead);
      const photo = await conversations.image(ctx.db, me.id, id(ctx));
      return image(photo.contentType, photo.bytes);
    },
  },
  {
    method: "PUT",
    pattern: "/messages/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const messageId = id(ctx);
      const text = conversations.parseBody(await body(ctx, 32 * 1024));
      return json(200, await conversations.edit(ctx.db, me.id, messageId, text));
    },
  },
  {
    method: "DELETE",
    pattern: "/messages/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await conversations.remove(ctx.db, me.id, id(ctx));
      return noContent();
    },
  },
  {
    method: "PUT",
    pattern: "/messages/:id/reaction",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const messageId = id(ctx);
      const emoji = conversations.parseEmoji(await body(ctx, 256));
      return json(200, await conversations.react(ctx.db, me.id, messageId, emoji));
    },
  },

  // ------------------------------------------------------------ skupiny
  {
    method: "POST",
    pattern: "/groups",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatGroupCreate);
      const input = await body(ctx, 8 * 1024);
      const title = groups.parseTitle(input);
      const members = conversations.parseUserIds(input.memberIds ?? []);
      return json(201, await groups.create(ctx.db, me.id, title, members));
    },
  },
  {
    method: "POST",
    pattern: "/groups/join",
    async handler(ctx) {
      const me = await ctx.user();
      if (
        !(await ctx.limiter.tryAcquire(limits.groupJoin, me.id)) ||
        !(await ctx.limiter.tryAcquire(limits.groupJoinIp, ctx.ip))
      ) {
        throw slowDown();
      }
      const code = (await body(ctx, 256)).code;
      return json(200, await groups.join(ctx.db, me.id, typeof code === "string" ? code : ""));
    },
  },
  {
    method: "PUT",
    pattern: "/groups/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const convId = id(ctx);
      await groups.rename(ctx.db, me.id, convId, groups.parseTitle(await body(ctx, 1024)));
      return noContent();
    },
  },
  {
    method: "DELETE",
    pattern: "/groups/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await groups.remove(ctx.db, me.id, id(ctx));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/groups/:id/members",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const convId = id(ctx);
      const members = conversations.parseUserIds((await body(ctx, 8 * 1024)).userIds);
      return json(200, { added: await groups.addMembers(ctx.db, me.id, convId, members) });
    },
  },
  {
    method: "DELETE",
    pattern: "/groups/:id/members/:userId",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await groups.removeMember(ctx.db, me.id, id(ctx), id(ctx, "userId"));
      return noContent();
    },
  },
  {
    method: "PUT",
    pattern: "/groups/:id/members/:userId",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      const convId = id(ctx);
      const memberId = id(ctx, "userId");
      await groups.setRole(ctx.db, me.id, convId, memberId, groups.parseRole(await body(ctx, 256)));
      return noContent();
    },
  },
  {
    method: "POST",
    pattern: "/groups/:id/invite",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatGroupCreate);
      return json(201, await groups.newInvite(ctx.db, me.id, id(ctx)));
    },
  },
  {
    method: "DELETE",
    pattern: "/groups/:id/invite",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await groups.disableInvite(ctx.db, me.id, id(ctx));
      return noContent();
    },
  },

  // ------------------------------------------------- kontakty a blokovanie
  {
    method: "GET",
    pattern: "/chat/contacts",
    handler: async (ctx) => json(200, { contacts: await conversations.contacts(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "GET",
    pattern: "/chat/blocks",
    handler: async (ctx) => json(200, { blocks: await conversations.blocks(ctx.db, (await ctx.user()).id) }),
  },
  {
    method: "PUT",
    pattern: "/chat/blocks/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await conversations.block(ctx.db, me.id, id(ctx));
      return noContent();
    },
  },
  {
    method: "DELETE",
    pattern: "/chat/blocks/:id",
    async handler(ctx) {
      const me = await limited(ctx, limits.chatWrite);
      await conversations.unblock(ctx.db, me.id, id(ctx));
      return noContent();
    },
  },
];
