// Chat a upozornenia proti skutočnej databáze (rovnako ako api.integration.test.ts).
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

async function call(method: string, path: string, token?: string, body?: unknown): Promise<{ status: number; body: Json }> {
  const headers: Record<string, string> = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const request = new Request(`http://localhost/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const response = await handleApi(request, path.split("?")[0], {
    connect: (fn) => withDb(fn, url),
    limiter: () => noLimits,
    onError: (e) => console.error(e),
  });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : {} };
}

type Account = { token: string; id: string };
const accounts: Account[] = [];

async function register(name: string, role = "member"): Promise<Account> {
  const res = await call("POST", "/auth/register", undefined, {
    email: `${name}-${run}@test.local`,
    password: "tajneheslo1",
    displayName: name,
    role,
  });
  expect(res.status).toBe(201);
  const account = { token: res.body.token, id: res.body.user.id };
  accounts.push(account);
  return account;
}

/** Tréner, klient a ich aktívne prepojenie. */
async function linkedPair(tag: string) {
  const trainer = await register(`chattrener-${tag}`, "trainer");
  const client = await register(`chatklient-${tag}`);
  const added = await call("POST", "/clients", trainer.token, { name: `Klient ${tag}` });
  const linkId = added.body.id as string;
  const invite = await call("POST", `/clients/${linkId}/invite`, trainer.token);
  const accepted = await call("POST", "/invites/accept", client.token, { code: invite.body.code });
  expect(accepted.status).toBe(200);
  return { trainer, client, linkId };
}

describe.skipIf(!url)("chat a upozornenia", () => {
  afterAll(async () => {
    for (const a of accounts) await call("DELETE", "/me", a.token);
  });

  it("tréner a klient si píšu, neprečítané sa rátajú a po otvorení zmiznú", async () => {
    const { trainer, client, linkId } = await linkedPair("a");

    // Aktívne prepojenie je v zozname aj bez správ.
    let res = await call("GET", "/chats", client.token);
    expect(res.body.chats).toEqual([
      expect.objectContaining({ linkId, otherRole: "trainer", canSend: true, unread: 0, lastMessage: null }),
    ]);

    res = await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "  Ahoj, ako sa máš?  " });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ body: "Ahoj, ako sa máš?", mine: true });
    await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "Zajtra nohy." });

    res = await call("GET", "/chats", client.token);
    expect(res.body.chats[0]).toMatchObject({ unread: 2, lastMessage: { body: "Zajtra nohy.", mine: false } });
    res = await call("GET", "/notifications", client.token);
    expect(res.body.unreadMessages).toBe(2);

    res = await call("GET", `/chats/${linkId}/messages`, client.token);
    expect(res.body.messages.map((m: Json) => m.body)).toEqual(["Ahoj, ako sa máš?", "Zajtra nohy."]);
    expect(res.body.messages.every((m: Json) => m.mine === false)).toBe(true);
    res = await call("GET", "/notifications", client.token);
    expect(res.body.unreadMessages).toBe(0);

    // Priebežné načítanie vráti len novšie správy.
    const last = (await call("GET", `/chats/${linkId}/messages`, client.token)).body.messages[1].sentAt as string;
    await call("POST", `/chats/${linkId}/messages`, client.token, { body: "Super, dík!" });
    res = await call("GET", `/chats/${linkId}/messages?after=${encodeURIComponent(last)}`, trainer.token);
    expect(res.body.messages.map((m: Json) => m.body)).toEqual(["Super, dík!"]);
  });

  it("cudzí človek konverzáciu nevidí ani do nej nepíše", async () => {
    const { trainer, linkId } = await linkedPair("b");
    await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "Tajné" });
    const stranger = await register("chatcudzi-b");

    expect((await call("GET", `/chats/${linkId}/messages`, stranger.token)).status).toBe(404);
    expect((await call("POST", `/chats/${linkId}/messages`, stranger.token, { body: "Ahoj" })).status).toBe(404);
    expect((await call("GET", "/chats", stranger.token)).body.chats).toEqual([]);
  });

  it("po ukončení spolupráce sa správy dajú čítať, ale nie písať", async () => {
    const { trainer, client, linkId } = await linkedPair("c");
    await call("POST", `/chats/${linkId}/messages`, client.token, { body: "Ďakujem za všetko" });
    expect((await call("POST", `/me/trainers/${linkId}/end`, client.token)).status).toBe(204);

    let res = await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "Ešte niečo" });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("chat_closed");
    res = await call("GET", "/chats", trainer.token);
    expect(res.body.chats).toEqual([expect.objectContaining({ linkId, canSend: false })]);
    res = await call("GET", `/chats/${linkId}/messages`, trainer.token);
    expect(res.body.messages).toHaveLength(1);
  });

  it("prázdna alebo príliš dlhá správa neprejde", async () => {
    const { trainer, linkId } = await linkedPair("d");
    expect((await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "   " })).status).toBe(400);
    expect((await call("POST", `/chats/${linkId}/messages`, trainer.token, { body: "x".repeat(4001) })).status).toBe(400);
  });

  it("udalosti od trénera a klienta vytvoria upozornenia pre druhú stranu", async () => {
    const { trainer, client, linkId } = await linkedPair("e");

    // Prijatá pozvánka → tréner.
    let res = await call("GET", "/notifications", trainer.token);
    expect(res.body.notifications[0]).toMatchObject({ kind: "link", linkId, read: false });
    expect(res.body.unread).toBe(1);

    // Nový plán → klient (nie tréner, ten ho sám vytvoril).
    const [exercise] = (await call("GET", "/exercises", trainer.token)).body.exercises;
    res = await call("POST", `/clients/${linkId}/workouts`, trainer.token, {
      title: "Nohy",
      exercises: [{ exerciseId: exercise.id, sets: 3, reps: 8 }],
    });
    expect(res.status).toBe(201);
    res = await call("GET", "/notifications", client.token);
    expect(res.body.notifications[0]).toMatchObject({ kind: "plan", title: "Nový plán od trénera", linkId });
    expect(res.body.notifications[0].body).toContain("Nohy");
    expect((await call("GET", "/notifications", trainer.token)).body.unread).toBe(1);

    // Označenie ako prečítané a zmazanie.
    const id = res.body.notifications[0].id as string;
    expect((await call("POST", "/notifications/read", client.token, { id })).status).toBe(204);
    res = await call("GET", "/notifications", client.token);
    expect(res.body.unread).toBe(0);
    expect((await call("POST", "/notifications/read", trainer.token, { id })).status).toBe(404);
    expect((await call("DELETE", `/notifications/${id}`, trainer.token)).status).toBe(404);
    expect((await call("DELETE", `/notifications/${id}`, client.token)).status).toBe(204);

    // Ukončenie spolupráce klientom → tréner.
    await call("POST", "/notifications/read", trainer.token, {});
    await call("POST", `/me/trainers/${linkId}/end`, client.token);
    res = await call("GET", "/notifications", trainer.token);
    expect(res.body.unread).toBe(1);
    expect(res.body.notifications[0]).toMatchObject({ kind: "link_ended" });
  });
});
