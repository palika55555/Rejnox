// Jedálničky proti skutočnej databáze (ako api.integration.test.ts). Bez databázy sa preskočia.
import { config } from "dotenv";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { withDb } from "./db";
import { handleApi } from "./router";

config({ path: ".env.local", quiet: true });
const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

const run = Math.random().toString(36).slice(2, 8);
let ipCounter = 0;

async function call(method: string, path: string, token?: string, body?: unknown) {
  const headers: Record<string, string> = { "cf-connecting-ip": `meal-${run}-${++ipCounter}` };
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const request = new Request(`http://localhost/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const response = await handleApi(request, path, { connect: (fn) => withDb(fn, url) });
  const text = await response.text();
  return { status: response.status, body: (text ? JSON.parse(text) : {}) as Json };
}

type Account = { token: string; id: string };
const accounts: Account[] = [];

async function register(name: string, role: string): Promise<Account> {
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

const today = () => new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Bratislava" });
const weekdayOf = (day: string) => (new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7;

describe.skipIf(!url)("jedálničky proti databáze", () => {
  let coach: Account;
  let client: Account;
  let other: Account;
  let linkId: string;
  let soloId: string;

  beforeAll(async () => {
    coach = await register("jedalcoach", "trainer");
    client = await register("jedalklient", "member");
    other = await register("jedalcudzi", "trainer");
    let res = await call("POST", "/clients", coach.token, { name: "Klientka" });
    linkId = res.body.id;
    res = await call("POST", `/clients/${linkId}/invite`, coach.token);
    res = await call("POST", "/invites/accept", client.token, { code: res.body.code });
    expect(res.status).toBe(200);
    res = await call("POST", "/clients", coach.token, { name: "Bez účtu" });
    soloId = res.body.id;
  });

  afterAll(async () => {
    for (const a of accounts) await call("DELETE", "/me", a.token);
  });

  const plan = (day: number) => ({
    title: "Týždeň 1",
    targets: { kcal: 2100, proteinG: 150 },
    items: [
      { day, meal: "Raňajky", name: "Vajíčka", amount: "3 ks", kcal: 240, proteinG: 18, carbsG: 2, fatG: 16 },
      { day, meal: "Obed", name: "Kuracie s ryžou", kcal: 650, proteinG: 45, carbsG: 80, fatG: 12 },
    ],
  });

  it("koncept klient nevidí, po odoslaní áno a dostane upozornenie; odškrtnutie vidí tréner", async () => {
    const day = today();
    let res = await call("POST", `/clients/${linkId}/meal-plans`, coach.token, plan(weekdayOf(day)));
    expect(res.status).toBe(201);
    const planId = res.body.id;
    expect(res.body.items).toHaveLength(2);
    expect(res.body.sentAt).toBeNull();

    res = await call("GET", "/me/meal-plans", client.token);
    expect(res.body.mealPlans).toHaveLength(0);

    res = await call("POST", `/clients/${linkId}/meal-plans/${planId}/send`, coach.token);
    expect(res.status).toBe(200);
    expect(res.body.sentAt).not.toBeNull();

    res = await call("GET", "/me/meal-plans", client.token);
    expect(res.body.mealPlans).toHaveLength(1);
    const [eggs, lunch] = res.body.mealPlans[0].items;

    res = await call("GET", "/notifications", client.token);
    expect(res.body.notifications.some((n: Json) => n.kind === "meal_plan")).toBe(true);

    expect((await call("PUT", `/me/meal-items/${eggs.id}/checks/${day}`, client.token)).status).toBe(204);
    // Opakované odškrtnutie nevadí.
    expect((await call("PUT", `/me/meal-items/${eggs.id}/checks/${day}`, client.token)).status).toBe(204);

    res = await call("GET", `/clients/${linkId}/progress`, coach.token);
    expect(res.status).toBe(200);
    expect(res.body.nutrition.days.at(-1)).toMatchObject({ plannedMeals: 2, eatenMeals: 1, eatenKcal: 240 });
    expect(res.body.nutrition.adherencePct).toBe(50);

    // Úprava zachová odškrtnutie pri jedle s rovnakým ID, zmazané jedlo zmizne.
    res = await call("PUT", `/clients/${linkId}/meal-plans/${planId}`, coach.token, {
      ...plan(weekdayOf(day)),
      items: [{ ...plan(weekdayOf(day)).items[0], id: eggs.id, name: "Vajíčka natvrdo" }],
    });
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(1);
    res = await call("GET", "/me/meal-plans", client.token);
    expect(res.body.mealPlans[0].checks).toEqual([{ itemId: eggs.id, eatenOn: day }]);
    expect((await call("PUT", `/me/meal-items/${lunch.id}/checks/${day}`, client.token)).status).toBe(404);

    expect((await call("DELETE", `/me/meal-items/${eggs.id}/checks/${day}`, client.token)).status).toBe(204);
  });

  it("cudzí tréner ani klient jedálniček nezmenia", async () => {
    let res = await call("POST", `/clients/${linkId}/meal-plans`, coach.token, plan(0));
    const planId = res.body.id;
    expect((await call("GET", `/clients/${linkId}/meal-plans/${planId}`, other.token)).status).toBe(404);
    expect((await call("GET", `/clients/${linkId}/meal-plans`, other.token)).status).toBe(404);
    expect((await call("GET", `/clients/${linkId}/progress`, other.token)).status).toBe(404);
    expect((await call("POST", `/clients/${linkId}/meal-plans`, client.token, plan(0))).status).toBe(403);
    // Neodoslaný jedálniček klient odškrtnúť nemôže.
    res = await call("GET", `/clients/${linkId}/meal-plans/${planId}`, coach.token);
    const itemId = res.body.items[0].id;
    expect((await call("PUT", `/me/meal-items/${itemId}/checks/${today()}`, client.token)).status).toBe(404);
  });

  it("klientovi bez účtu sa nedá poslať, ale dá sa mu skopírovať jedálniček", async () => {
    let res = await call("POST", `/clients/${soloId}/meal-plans`, coach.token, plan(2));
    const planId = res.body.id;
    res = await call("POST", `/clients/${soloId}/meal-plans/${planId}/send`, coach.token);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("client_not_linked");

    res = await call("POST", `/clients/${soloId}/meal-plans/${planId}/copy`, coach.token, { clientId: linkId });
    expect(res.status).toBe(201);
    expect(res.body.clientId).toBe(linkId);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.sentAt).toBeNull();

    res = await call("GET", `/clients/${soloId}/meal-plans`, coach.token);
    expect(res.body.mealPlans[0]).toMatchObject({ itemCount: 2, avgKcal: 890 });

    expect((await call("DELETE", `/clients/${soloId}/meal-plans/${planId}`, coach.token)).status).toBe(204);
    expect((await call("GET", `/clients/${soloId}/meal-plans/${planId}`, coach.token)).status).toBe(404);
  });

  it("prázdny jedálniček sa neodošle", async () => {
    let res = await call("POST", `/clients/${linkId}/meal-plans`, coach.token, { title: "Prázdny" });
    res = await call("POST", `/clients/${linkId}/meal-plans/${res.body.id}/send`, coach.token);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe("empty_plan");
  });
});
