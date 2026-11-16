// Chat so skupinami proti skutočnej databáze (rovnako ako chat.integration.test.ts).
// Bez databázy sa testy preskočia.
import { config } from "dotenv";
import { afterAll, describe, expect, it } from "vitest";
import { withDb } from "./db";
import type { RateLimiter } from "./rateLimit";
import { handleApi } from "./router";

config({ path: ".env.local", quiet: true });
const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

const run = Math.random().toString(36).slice(2, 8);
/** Limity pokusov tu netestujeme. */
const noLimits: RateLimiter = { tryAcquire: async () => true, reset: async () => undefined };

/** Najmenší platný PNG (1×1 px). */
const PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="),
  (c) => c.charCodeAt(0),
);

async function call(
  method: string,
  path: string,
  token?: string,
  body?: unknown,
): Promise<{ status: number; body: Json; bytes: Uint8Array }> {
  const headers: Record<string, string> = {};
  if (token) headers.authorization = `Bearer ${token}`;
  let payload: BodyInit | undefined;
  if (body instanceof Uint8Array) {
    headers["content-type"] = "image/png";
    payload = body as BodyInit;
  } else if (body !== undefined) {
    headers["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const request = new Request(`http://localhost/api${path}`, { method, headers, body: payload });
  const response = await handleApi(request, path.split("?")[0], {
    connect: (fn) => withDb(fn, url),
    limiter: () => noLimits,
    onError: (e) => console.error(e),
  });
  const bytes = new Uint8Array(await response.arrayBuffer());
  const isJson = response.headers.get("content-type")?.includes("json") && bytes.length > 0;
  return { status: response.status, body: isJson ? JSON.parse(new TextDecoder().decode(bytes)) : {}, bytes };
}

type Account = { token: string; id: string; name: string };
const accounts: Account[] = [];

async function register(name: string, role = "member"): Promise<Account> {
  const res = await call("POST", "/auth/register", undefined, {
    email: `${name}-${run}@test.local`,
    password: "tajneheslo1",
    displayName: name,
    role,
  });
  expect(res.status).toBe(201);
  const account = { token: res.body.token, id: res.body.user.id, name };
  accounts.push(account);
  return account;
}

async function link(trainer: Account, client: Account): Promise<string> {
  const added = await call("POST", "/clients", trainer.token, { name: client.name });
  const linkId = added.body.id as string;
  const invite = await call("POST", `/clients/${linkId}/invite`, trainer.token);
  const accepted = await call("POST", "/invites/accept", client.token, { code: invite.body.code });
  expect(accepted.status).toBe(200);
  return linkId;
}

/** Tréner s dvoma klientmi a jeden cudzí človek. */
async function team(tag: string) {
  const trainer = await register(`gtrener-${tag}`, "trainer");
  const anna = await register(`ganna-${tag}`);
  const boris = await register(`gboris-${tag}`);
  const stranger = await register(`gcudzi-${tag}`);
  await link(trainer, anna);
  await link(trainer, boris);
  return { trainer, anna, boris, stranger };
}

const messages = (who: Account, conv: string, query = "") =>
  call("GET", `/conversations/${conv}/messages${query}`, who.token);

describe.skipIf(!url)("chat: skupiny a súkromné správy", () => {
  afterAll(async () => {
    for (const a of accounts) await call("DELETE", "/me", a.token);
  });

  it("skupina: založenie, správy, odpovede, úpravy, reakcie a zmazanie", async () => {
    const { trainer, anna, boris, stranger } = await team("a");

    // Cudzieho (bez prepojenia ani spoločnej skupiny) pridať nejde.
    let res = await call("POST", "/groups", trainer.token, { title: "Ranný beh", memberIds: [anna.id, stranger.id] });
    expect(res.status).toBe(403);

    res = await call("POST", "/groups", trainer.token, { title: "  Ranný   beh ", memberIds: [anna.id] });
    expect(res.status).toBe(201);
    const group = res.body.id as string;

    res = await call("GET", `/conversations/${group}`, anna.token);
    expect(res.body).toMatchObject({ kind: "group", title: "Ranný beh", myRole: "member", memberCount: 2 });
    expect(res.body.members.map((m: Json) => m.role).sort()).toEqual(["admin", "member"]);

    res = await call("POST", `/conversations/${group}/messages`, trainer.token, { body: "Zajtra o 7:00" });
    expect(res.status).toBe(201);
    const first = res.body;
    expect(first).toMatchObject({ kind: "text", mine: true, senderName: trainer.name });

    // Anna vidí od svojho pridania: systémovú správu a správu trénera. Odpovie na ňu.
    res = await messages(anna, group);
    expect(res.body.messages.map((m: Json) => m.kind)).toEqual(["system", "text"]);
    expect(res.body.canSend).toBe(true);
    res = await call("POST", `/conversations/${group}/messages`, anna.token, { body: "Budem tam", replyTo: first.id });
    expect(res.body.replyTo).toMatchObject({ id: first.id, body: "Zajtra o 7:00", senderName: trainer.name });
    const reply = res.body;

    // Boris príde neskôr a staršie správy nevidí.
    res = await call("POST", `/groups/${group}/members`, trainer.token, { userIds: [boris.id] });
    expect(res.body.added).toBe(1);
    res = await messages(boris, group);
    expect(res.body.messages.map((m: Json) => m.kind)).toEqual(["system"]);
    res = await call("PUT", `/messages/${first.id}/reaction`, boris.token, { emoji: "👍" });
    expect(res.status).toBe(404);

    // Úprava a reakcia sa prejavia v priebežnom načítaní (?since=).
    const since = encodeURIComponent(reply.updatedAt);
    res = await call("PUT", `/messages/${first.id}`, trainer.token, { body: "Zajtra o 7:30" });
    expect(res.body).toMatchObject({ body: "Zajtra o 7:30", edited: true });
    res = await call("PUT", `/messages/${reply.id}/reaction`, trainer.token, { emoji: "🔥" });
    expect(res.body.reactions).toEqual([{ emoji: "🔥", count: 1, mine: true }]);
    res = await call("PUT", `/messages/${reply.id}/reaction`, trainer.token, { emoji: "💩" });
    expect(res.status).toBe(400);
    res = await messages(anna, group, `?since=${since}`);
    const changed = Object.fromEntries(res.body.messages.map((m: Json) => [m.id, m]));
    expect(changed[first.id]).toMatchObject({ body: "Zajtra o 7:30", edited: true });
    expect(changed[reply.id].reactions).toEqual([{ emoji: "🔥", count: 1, mine: false }]);

    // Cudziu správu upraviť ani zmazať nejde; správca skupiny ju zmazať smie.
    expect((await call("PUT", `/messages/${first.id}`, anna.token, { body: "hack" })).status).toBe(404);
    expect((await call("DELETE", `/messages/${first.id}`, anna.token)).status).toBe(404);
    expect((await call("DELETE", `/messages/${reply.id}`, trainer.token)).status).toBe(204);
    res = await messages(anna, group);
    expect(res.body.messages.find((m: Json) => m.id === reply.id)).toMatchObject({
      deleted: true,
      body: null,
      reactions: [],
    });

    // Cudzí nič nevidí a nič nezapíše.
    expect((await messages(stranger, group)).status).toBe(404);
    expect((await call("GET", `/conversations/${group}`, stranger.token)).status).toBe(404);
    expect((await call("POST", `/conversations/${group}/messages`, stranger.token, { body: "ahoj" })).status).toBe(404);
    expect((await call("POST", `/groups/${group}/members`, stranger.token, { userIds: [stranger.id] })).status).toBe(403);
  });

  it("skupina: práva správcu, odchod a odovzdanie správcovstva", async () => {
    const { trainer, anna, boris } = await team("b");
    const group = (await call("POST", "/groups", trainer.token, { title: "Tím", memberIds: [anna.id, boris.id] })).body
      .id as string;

    // Bežný člen nepremenuje, nepridá ani neodoberie.
    expect((await call("PUT", `/groups/${group}`, anna.token, { title: "Môj" })).status).toBe(403);
    expect((await call("DELETE", `/groups/${group}/members/${boris.id}`, anna.token)).status).toBe(403);
    expect((await call("PUT", `/groups/${group}/members/${anna.id}`, anna.token, { role: "admin" })).status).toBe(403);
    expect((await call("DELETE", `/groups/${group}`, anna.token)).status).toBe(403);

    expect((await call("PUT", `/groups/${group}`, trainer.token, { title: "Tím 2" })).status).toBe(204);
    expect((await call("GET", `/conversations/${group}`, anna.token)).body.title).toBe("Tím 2");

    // Odobratý člen stratí prístup.
    expect((await call("DELETE", `/groups/${group}/members/${boris.id}`, trainer.token)).status).toBe(204);
    expect((await messages(boris, group)).status).toBe(404);

    // Posledný správca nesmie zostať bez náhrady, odchodom ju dostane najdlhší člen.
    expect((await call("PUT", `/groups/${group}/members/${trainer.id}`, trainer.token, { role: "member" })).status).toBe(400);
    expect((await call("DELETE", `/groups/${group}/members/${trainer.id}`, trainer.token)).status).toBe(204);
    const res = await call("GET", `/conversations/${group}`, anna.token);
    expect(res.body).toMatchObject({ myRole: "admin", memberCount: 1 });

    // Posledný odchod skupinu zruší.
    expect((await call("DELETE", `/groups/${group}/members/${anna.id}`, anna.token)).status).toBe(204);
    expect((await call("GET", `/conversations/${group}`, anna.token)).status).toBe(404);
  });

  it("pozývací kód: vstup, zlý kód, zrušenie", async () => {
    const { trainer, stranger } = await team("c");
    const group = (await call("POST", "/groups", trainer.token, { title: "Otvorená", memberIds: [] })).body.id as string;

    let res = await call("POST", `/groups/${group}/invite`, stranger.token);
    expect(res.status).toBe(403);
    res = await call("POST", `/groups/${group}/invite`, trainer.token);
    expect(res.status).toBe(201);
    const code = res.body.code as string;
    expect(code).toMatch(/^[A-Z2-9]{4}-[A-Z2-9]{4}$/);

    expect((await call("POST", "/groups/join", stranger.token, { code: "AAAA-BBBB" })).status).toBe(404);
    expect((await call("POST", "/groups/join", stranger.token, { code: "zlé" })).status).toBe(400);
    res = await call("POST", "/groups/join", stranger.token, { code: code.toLowerCase().replace("-", " ") });
    expect(res.body.id).toBe(group);
    expect((await call("GET", `/conversations/${group}`, trainer.token)).body.hasInvite).toBe(true);

    // Po zrušení kód neplatí; nový kód nahradí starý.
    await call("DELETE", `/groups/${group}/invite`, trainer.token);
    const other = await register("gdalsi-c");
    expect((await call("POST", "/groups/join", other.token, { code })).status).toBe(404);
    const fresh = (await call("POST", `/groups/${group}/invite`, trainer.token)).body.code as string;
    expect((await call("POST", "/groups/join", other.token, { code: fresh })).status).toBe(200);
  });

  it("súkromné správy len medzi známymi, blokovanie ich zastaví", async () => {
    const { trainer, anna, boris, stranger } = await team("d");

    // Klienti toho istého trénera sa nepoznajú.
    expect((await call("POST", "/conversations/direct", anna.token, { userId: boris.id })).status).toBe(403);
    expect((await call("POST", "/conversations/direct", anna.token, { userId: stranger.id })).status).toBe(403);
    let contacts = (await call("GET", "/chat/contacts", anna.token)).body.contacts as Json[];
    expect(contacts.map((c) => c.id)).toEqual([trainer.id]);

    // S trénerom vráti ich konverzáciu k prepojeniu (nie novú).
    const withTrainer = (await call("POST", "/conversations/direct", anna.token, { userId: trainer.id })).body.id;
    expect((await call("GET", `/conversations/${withTrainer}`, anna.token)).body.kind).toBe("link");

    // Po spoločnej skupine sa poznajú.
    await call("POST", "/groups", trainer.token, { title: "Spolu", memberIds: [anna.id, boris.id] });
    contacts = (await call("GET", "/chat/contacts", anna.token)).body.contacts as Json[];
    expect(contacts.map((c) => c.id).sort()).toEqual([trainer.id, boris.id].sort());
    const res = await call("POST", "/conversations/direct", anna.token, { userId: boris.id });
    expect(res.status).toBe(200);
    const dm = res.body.id as string;
    expect((await call("POST", "/conversations/direct", boris.token, { userId: anna.id })).body.id).toBe(dm);
    expect((await call("POST", `/conversations/${dm}/messages`, anna.token, { body: "Ahoj Boris" })).status).toBe(201);

    // Boris Annu zablokuje: písať si nemôžu, nová konverzácia nevznikne.
    expect((await call("PUT", `/chat/blocks/${anna.id}`, boris.token)).status).toBe(204);
    expect((await call("POST", `/conversations/${dm}/messages`, anna.token, { body: "Haló?" })).status).toBe(403);
    expect((await call("POST", `/conversations/${dm}/messages`, boris.token, { body: "Haló?" })).status).toBe(403);
    expect((await messages(anna, dm)).body.canSend).toBe(false);
    expect((await call("GET", `/conversations/${dm}`, boris.token)).body.blocked).toBe(true);
    expect((await call("GET", "/chat/blocks", boris.token)).body.blocks.map((b: Json) => b.id)).toEqual([anna.id]);

    expect((await call("DELETE", `/chat/blocks/${anna.id}`, boris.token)).status).toBe(204);
    expect((await call("POST", `/conversations/${dm}/messages`, anna.token, { body: "Už to ide" })).status).toBe(201);

    // Blokovanie platí aj v chate tréner–klient.
    await call("PUT", `/chat/blocks/${trainer.id}`, anna.token);
    expect((await call("POST", `/conversations/${withTrainer}/messages`, trainer.token, { body: "Haló" })).status).toBe(403);
    await call("DELETE", `/chat/blocks/${trainer.id}`, anna.token);
  });

  it("po odobratí zo skupiny sa zavrie súkromný chat aj starý kód", async () => {
    const { trainer, anna, stranger } = await team("f");
    const group = (await call("POST", "/groups", trainer.token, { title: "Kód", memberIds: [anna.id] })).body.id;
    const code = (await call("POST", `/groups/${group}/invite`, trainer.token)).body.code;
    expect((await call("POST", "/groups/join", stranger.token, { code })).status).toBe(200);

    // Cudzí sa cez skupinu „zoznámil“ s Annou a napísal jej.
    const dm = (await call("POST", "/conversations/direct", stranger.token, { userId: anna.id })).body.id;
    expect((await call("POST", `/conversations/${dm}/messages`, stranger.token, { body: "Ahoj" })).status).toBe(201);

    // Správca ho odoberie: súkromný chat sa zavrie a starý kód prestane platiť.
    expect((await call("DELETE", `/groups/${group}/members/${stranger.id}`, trainer.token)).status).toBe(204);
    expect((await call("POST", `/conversations/${dm}/messages`, stranger.token, { body: "Haló?" })).status).toBe(403);
    expect((await call("POST", "/conversations/direct", stranger.token, { userId: anna.id })).status).toBe(403);
    expect((await call("POST", "/groups/join", stranger.token, { code })).status).toBe(404);
    expect((await call("GET", `/conversations/${group}`, trainer.token)).body.hasInvite).toBe(false);
  });

  it("fotky, neprečítané, stlmenie a starý chat", async () => {
    const { trainer, anna, stranger } = await team("e");
    const linkId = (await call("GET", "/chats", anna.token)).body.chats[0].linkId as string;
    const conv = (await call("POST", `/conversations/link/${linkId}`, anna.token)).body.id as string;
    expect((await call("POST", `/conversations/link/${linkId}`, stranger.token)).status).toBe(404);

    let res = await call("POST", `/conversations/${conv}/images`, trainer.token, PNG);
    expect(res.status).toBe(201);
    const photo = res.body;
    expect(photo).toMatchObject({ kind: "image", body: null });
    expect((await call("POST", `/conversations/${conv}/images`, trainer.token, new Uint8Array([1, 2, 3]))).status).toBe(
      415,
    );

    res = await call("GET", `/chat-images/${photo.id}`, anna.token);
    expect(res.status).toBe(200);
    expect(res.bytes).toEqual(PNG);
    expect((await call("GET", `/chat-images/${photo.id}`, stranger.token)).status).toBe(404);

    // Neprečítané v zozname aj v upozorneniach; stlmená konverzácia sa do odznaku nerátá.
    await call("POST", `/conversations/${conv}/messages`, trainer.token, { body: "Ako ide tréning?" });
    let list = (await call("GET", "/conversations", anna.token)).body.conversations as Json[];
    expect(list.find((c) => c.id === conv)).toMatchObject({ kind: "link", unread: 2, title: trainer.name });
    expect((await call("GET", "/notifications", anna.token)).body.unreadMessages).toBe(2);
    expect((await call("PUT", `/conversations/${conv}/mute`, anna.token, { muted: true })).status).toBe(204);
    expect((await call("GET", "/notifications", anna.token)).body.unreadMessages).toBe(0);
    await call("PUT", `/conversations/${conv}/mute`, anna.token, { muted: false });

    // Po otvorení je všetko prečítané a tréner vidí, dokedy Anna čítala.
    const page = (await messages(anna, conv)).body;
    list = (await call("GET", "/conversations", anna.token)).body.conversations as Json[];
    expect(list.find((c) => c.id === conv)?.unread).toBe(0);
    const readBy = (await messages(trainer, conv)).body.readBy as Json[];
    expect(Date.parse(readBy[0].lastReadAt)).toBeGreaterThanOrEqual(Date.parse(page.messages.at(-1).sentAt));

    // Píše…
    expect((await call("POST", `/conversations/${conv}/typing`, trainer.token)).status).toBe(204);
    expect((await messages(anna, conv)).body.typing).toEqual([trainer.name]);

    // Starý chat (staršie appky) dostane namiesto fotky a zmazanej správy text.
    await call("DELETE", `/messages/${photo.id}`, trainer.token);
    const old = (await call("GET", `/chats/${linkId}/messages`, anna.token)).body.messages as Json[];
    expect(old.map((m) => m.body)).toEqual(["Správa bola odstránená.", "Ako ide tréning?"]);
  });
});
