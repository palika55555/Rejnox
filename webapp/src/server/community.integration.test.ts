// Komunita proti skutočnej databáze (ako chat.integration.test.ts).
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

async function register(name: string): Promise<Account> {
  const res = await call("POST", "/auth/register", undefined, {
    email: `${name}-${run}@test.local`,
    password: "tajneheslo1",
    displayName: name,
  });
  expect(res.status).toBe(201);
  const account = { token: res.body.token, id: res.body.user.id };
  accounts.push(account);
  return account;
}

const inHours = (h: number) => new Date(Date.now() + h * 3600_000).toISOString();

describe.skipIf(!url)("komunita", () => {
  afterAll(async () => {
    for (const a of accounts) await call("DELETE", "/me", a.token);
  });

  it("príspevok, lajk, komentár a upozornenie autorovi", async () => {
    const eva = await register(`keva-${run}`);
    const jan = await register(`kjan-${run}`);

    let res = await call("POST", "/community/posts", eva.token, { body: "  Nový rekord v drepe! " });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ body: "Nový rekord v drepe!", likes: 0, mine: true });
    const post = res.body.id as string;

    res = await call("PUT", `/community/posts/${post}/like`, jan.token);
    expect(res.body).toMatchObject({ likes: 1, likedByMe: true, mine: false });
    res = await call("PUT", `/community/posts/${post}/like`, jan.token);
    expect(res.body.likes).toBe(1);

    res = await call("POST", `/community/posts/${post}/comments`, jan.token, { body: "Gratulujem" });
    expect(res.status).toBe(201);
    const comment = res.body.id as string;

    res = await call("GET", "/community/posts", jan.token);
    expect(res.body.posts.find((p: Json) => p.id === post)).toMatchObject({ comments: 1, likes: 1 });

    res = await call("GET", "/notifications", eva.token);
    expect(res.body.notifications.map((n: Json) => n.kind)).toContain("community");

    // Cudzí príspevok zmazať nejde, komentár na svojom príspevku áno.
    expect((await call("DELETE", `/community/posts/${post}`, jan.token)).status).toBe(404);
    expect((await call("DELETE", `/community/comments/${comment}`, eva.token)).status).toBe(204);
    expect((await call("DELETE", `/community/posts/${post}/like`, jan.token)).body.likes).toBe(0);
    expect((await call("DELETE", `/community/posts/${post}`, eva.token)).status).toBe(204);
  });

  it("parťák na tréning, udalosť a domovská obrazovka", async () => {
    const host = await register(`khost-${run}`);
    const guest = await register(`kguest-${run}`);

    let res = await call("POST", "/community/buddies", host.token, { startsAt: inHours(3), place: "Fitko Nivy", focus: "Nohy" });
    expect(res.status).toBe(201);
    const session = res.body.id as string;

    expect((await call("PUT", `/community/buddies/${session}/join`, host.token)).status).toBe(409);
    const home = await call("GET", "/home", guest.token);
    expect(home.body.partnerRequest).toMatchObject({ id: session, place: "Fitko Nivy" });

    res = await call("PUT", `/community/buddies/${session}/join`, guest.token);
    expect(res.body).toMatchObject({ members: 1, joined: true });

    res = await call("POST", "/community/events", host.token, { title: "Sobotný beh", place: "Draždiak", startsAt: inHours(48) });
    expect(res.body).toMatchObject({ attendees: 1, joined: true, mine: true });
    const event = res.body.id as string;
    res = await call("PUT", `/community/events/${event}/join`, guest.token);
    expect(res.body.attendees).toBe(2);

    expect((await call("POST", "/community/events", host.token, { title: "X", place: "Y", startsAt: inHours(-5) })).status).toBe(400);
  });

  it("výzva a rebríček len so súhlasom", async () => {
    const ada = await register(`kada-${run}`);
    const today = new Date().toISOString().slice(0, 10);
    const later = new Date(Date.now() + 20 * 86_400_000).toISOString().slice(0, 10);

    let res = await call("POST", "/community/challenges", ada.token, { title: "10 tréningov", goalDays: 10, startsOn: today, endsOn: later });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ joined: true, members: 1, myDays: 0 });

    res = await call("GET", "/community/leaderboard", ada.token);
    expect(res.body.optedIn).toBe(false);
    expect((await call("GET", "/home", ada.token)).body.ranking).toBeNull();

    res = await call("PUT", "/community/leaderboard/opt-in", ada.token, { enabled: true });
    expect(res.body.optedIn).toBe(true);
    // Bez tréningu v rebríčku nie je (rátajú sa len dni s tréningom).
    expect(res.body.entries.some((e: Json) => e.me)).toBe(false);
  });
});
