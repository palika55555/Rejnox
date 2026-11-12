// Celé API proti skutočnej databáze (lokálny Postgres s migráciami, rola rejnox_app).
// Adresa sa berie z TEST_DATABASE_URL alebo z webapp/.env.local (DATABASE_URL).
// Bez databázy sa testy preskočia.
import { config } from "dotenv";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { withDb } from "./db";
import { handleApi } from "./router";

config({ path: ".env.local", quiet: true });
const url = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL;

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

const run = Math.random().toString(36).slice(2, 8);
/** Každý test má vlastnú "IP", aby sa limity pokusov neovplyvňovali. */
let ipCounter = 0;
const freshIp = () => `test-${run}-${++ipCounter}`;

async function call(
  method: string,
  path: string,
  { token, body, ip = freshIp() }: { token?: string; body?: unknown; ip?: string } = {},
): Promise<{ status: number; body: Json }> {
  const headers: Record<string, string> = { "cf-connecting-ip": ip };
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const request = new Request(`http://localhost/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const response = await handleApi(request, path, {
    connect: (fn) => withDb(fn, url),
    onError: (e) => console.error(e),
  });
  const text = await response.text();
  return { status: response.status, body: text ? JSON.parse(text) : {} };
}

type Account = { token: string; id: string; email: string };
const accounts: Account[] = [];

async function register(name: string, role = "member"): Promise<Account> {
  const email = `${name}-${run}@test.local`;
  const res = await call("POST", "/auth/register", {
    body: { email, password: "tajneheslo1", displayName: name, role },
  });
  expect(res.status).toBe(201);
  const account = { token: res.body.token, id: res.body.user.id, email };
  accounts.push(account);
  return account;
}

describe.skipIf(!url)("API proti databáze", () => {
  afterAll(async () => {
    for (const a of accounts) await call("DELETE", "/me", { token: a.token });
  });

  describe("účet", () => {
    it("registrácia, prihlásenie, odhlásenie a zmazanie účtu", async () => {
      const email = `pavol-${run}@test.local`;
      let res = await call("POST", "/auth/register", {
        body: { email: ` ${email.toUpperCase()} `, password: "tajneheslo1", displayName: "Pavol" },
      });
      expect(res.status).toBe(201);
      expect(res.body.user).toMatchObject({ email, displayName: "Pavol", role: "member" });
      const first = res.body.token as string;

      res = await call("POST", "/auth/register", {
        body: { email, password: "tajneheslo1", displayName: "Znova" },
      });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe("email_taken");

      res = await call("POST", "/auth/login", { body: { email, password: "zleheslo1" } });
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe("invalid_credentials");

      res = await call("POST", "/auth/login", { body: { email, password: "tajneheslo1" } });
      expect(res.status).toBe(200);
      const second = res.body.token as string;
      expect(second).not.toBe(first);

      res = await call("GET", "/me", { token: second });
      expect(res.body).toMatchObject({ email, displayName: "Pavol" });

      expect((await call("POST", "/auth/logout", { token: second })).status).toBe(204);
      expect((await call("GET", "/me", { token: second })).status).toBe(401);

      expect((await call("DELETE", "/me", { token: first })).status).toBe(204);
      expect((await call("GET", "/me", { token: first })).status).toBe(401);
      res = await call("POST", "/auth/login", { body: { email, password: "tajneheslo1" } });
      expect(res.status).toBe(401);
    });

    it("opakované zlé pokusy o prihlásenie sa zablokujú", async () => {
      const ip = freshIp();
      const email = `nikto-${run}@test.local`;
      const statuses: number[] = [];
      for (let i = 0; i < 11; i++) {
        statuses.push((await call("POST", "/auth/login", { ip, body: { email, password: "zleheslo1" } })).status);
      }
      expect(statuses.slice(0, 10).every((s) => s === 401)).toBe(true);
      expect(statuses[10]).toBe(429);
    });

    it("menenie IP neobíde limit pokusov na jeden e-mail", async () => {
      const email = `terc-${run}@test.local`;
      let last = 0;
      for (let i = 0; i < 31; i++) {
        last = (await call("POST", "/auth/login", { body: { email, password: "zleheslo1" } })).status;
      }
      expect(last).toBe(429);
    });

    it("jedna IP neoskúša heslá na veľa rôznych e-mailoch", async () => {
      const ip = freshIp();
      let last = 0;
      for (let i = 0; i < 51; i++) {
        last = (
          await call("POST", "/auth/login", { ip, body: { email: `sprej-${i}-${run}@test.local`, password: "zleheslo1" } })
        ).status;
      }
      expect(last).toBe(429);
    }, 60_000);

    it("neplatné vstupy vrátia 400 a neznáma cesta 404", async () => {
      expect((await call("POST", "/auth/register", { body: { email: "x" } })).status).toBe(400);
      const res = await call("GET", "/neexistuje");
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe("not_found");
      expect((await call("GET", "/me")).status).toBe(401);
      expect((await call("GET", "/health")).body).toEqual({ status: "ok" });
    });
  });

  describe("tréner a klient", () => {
    let coach: Account;
    let client: Account;
    let stranger: Account;
    const exerciseId = "00000000-0000-4000-8000-000000000001";

    beforeAll(async () => {
      coach = await register("coach", "trainer");
      client = await register("klient");
      stranger = await register("cudzi", "trainer");
    });

    it("člen nemôže pridávať klientov", async () => {
      const res = await call("GET", "/clients", { token: client.token });
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe("trainers_only");
    });

    it("celý tok: pridanie, pozvánka, plán, progres, ukončenie", async () => {
      let res = await call("POST", "/clients", { token: coach.token, body: { name: "Jana", note: "koleno" } });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ name: "Jana", note: "koleno", status: "record_only", hasAccount: false });
      const linkId = res.body.id as string;

      res = await call("POST", `/clients/${linkId}/invite`, { token: coach.token });
      expect(res.status).toBe(201);
      const inviteCode = res.body.code as string;

      res = await call("POST", "/invites/accept", { token: client.token, body: { code: "ZZZZ-ZZZZ" } });
      expect(res.status).toBe(404);
      res = await call("POST", "/invites/accept", { token: client.token, body: { code: inviteCode.toLowerCase() } });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ linkId, trainerName: "coach", status: "linked" });

      res = await call("POST", `/clients/${linkId}/workouts`, {
        token: coach.token,
        body: {
          title: "Nohy",
          scheduledOn: "2026-11-20",
          exercises: [{ exerciseId, sets: 3, reps: 8, weightKg: 60.5, note: "pomaly" }],
        },
      });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ title: "Nohy", scheduledOn: "2026-11-20", trainerName: "coach" });
      expect(res.body.exercises[0]).toMatchObject({ exerciseId, sets: 3, reps: 8, weightKg: 60.5, note: "pomaly" });

      const setId = crypto.randomUUID();
      const set = { id: setId, exerciseId, reps: 8, weightKg: 60 };
      expect((await call("POST", `/clients/${linkId}/sets`, { token: coach.token, body: set })).status).toBe(201);
      // Opakované odoslanie nič nezdvojí.
      expect((await call("POST", `/clients/${linkId}/sets`, { token: coach.token, body: set })).status).toBe(201);

      res = await call("GET", `/clients/${linkId}`, { token: coach.token });
      expect(res.body.hasAccount).toBe(true);
      expect(res.body.workouts).toHaveLength(1);
      expect(res.body.sets).toHaveLength(1);
      expect(typeof res.body.sets[0].performedAt).toBe("string");

      res = await call("GET", "/me/plans", { token: client.token });
      expect(res.body.plans.map((p: Json) => p.title)).toEqual(["Nohy"]);
      res = await call("GET", "/me/trainers", { token: client.token });
      expect(res.body.trainers).toHaveLength(1);

      // Klienta s účtom nejde zmazať.
      expect((await call("DELETE", `/clients/${linkId}`, { token: coach.token })).status).toBe(409);

      // Klient spoluprácu ukončí, tréner stratí prístup.
      expect((await call("POST", `/me/trainers/${linkId}/end`, { token: client.token })).status).toBe(204);
      res = await call("POST", `/clients/${linkId}/workouts`, {
        token: coach.token,
        body: { title: "Ďalší", exercises: [{ exerciseId, sets: 1, reps: 1 }] },
      });
      expect(res.status).toBe(404);
    });

    it("cudzí tréner na klienta nedosiahne", async () => {
      const res = await call("POST", "/clients", { token: coach.token, body: { name: "Tajný" } });
      const linkId = res.body.id as string;
      expect((await call("GET", `/clients/${linkId}`, { token: stranger.token })).status).toBe(404);
      expect((await call("POST", `/clients/${linkId}/invite`, { token: stranger.token })).status).toBe(409);
      expect((await call("DELETE", `/clients/${linkId}`, { token: stranger.token })).status).toBe(409);
      // Klient bez účtu sa zmazať dá.
      expect((await call("DELETE", `/clients/${linkId}`, { token: coach.token })).status).toBe(204);
    });

    it("hádanie pozývacích kódov sa zablokuje a platný kód limit nevynuluje", async () => {
      const guesser = await register("hadac");
      const statuses: number[] = [];
      for (let i = 0; i < 11; i++) {
        statuses.push((await call("POST", "/invites/accept", { token: guesser.token, body: { code: "ZZZZ-ZZZZ" } })).status);
      }
      expect(statuses.slice(0, 10).every((s) => s === 404)).toBe(true);
      expect(statuses[10]).toBe(429);
    });

    it("neplatné vstupy", async () => {
      expect((await call("GET", "/clients/nie-uuid", { token: coach.token })).status).toBe(400);
      expect((await call("POST", "/clients", { token: coach.token, body: { name: "" } })).status).toBe(400);
      const res = await call("POST", "/invites/accept", { token: client.token, body: { code: "123" } });
      expect(res.body.error.code).toBe("invalid_code");
    });
  });

  describe("tréningy", () => {
    let me: Account;
    beforeAll(async () => {
      me = await register("cvicenec");
    });

    it("katalóg cvikov", async () => {
      const res = await call("GET", "/exercises", { token: me.token });
      expect(res.body.exercises.length).toBeGreaterThanOrEqual(12);
      expect(res.body.exercises[0]).toHaveProperty("muscleGroup");
    });

    it("opakované odoslanie tej istej série ju nezdvojí, neznámy cvik sa odmietne", async () => {
      const id = crypto.randomUUID();
      const unknown = crypto.randomUUID();
      const sets = [
        { id, exerciseId: "00000000-0000-4000-8000-000000000004", reps: 5, weightKg: 80, performedAt: new Date().toISOString() },
        { id: unknown, exerciseId: crypto.randomUUID(), reps: 5, weightKg: 80, performedAt: new Date().toISOString() },
      ];
      let res = await call("POST", "/sets/sync", { token: me.token, body: { sets } });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ accepted: [id], rejected: [{ id: unknown, reason: "unknown_exercise" }] });
      res = await call("POST", "/sets/sync", { token: me.token, body: { sets: sets.slice(0, 1) } });
      expect(res.body.accepted).toEqual([id]);
    });

    it("bez prihlásenia nič", async () => {
      expect((await call("POST", "/sets/sync", { body: { sets: [] } })).status).toBe(401);
    });
  });

  describe("fitká", () => {
    let anna: Account;
    let boris: Account;
    let gymId: string;

    beforeAll(async () => {
      anna = await register("anna");
      boris = await register("boris");
      gymId = await withDb(
        (db) =>
          db.asUser(anna.id, async (tx) => {
            const [row] = await tx.query<{ id: string }>(
              `INSERT INTO gyms (name, city, lat, lng, created_by, opening_hours, tags)
               VALUES ($1, 'Nitra', 48.3, 18.08, $2::uuid, 'Nonstop', '{Kardio}') RETURNING id::text`,
              [`Test Gym ${run}`, anna.id],
            );
            return row.id;
          }),
        url,
      );
    });

    afterAll(async () => {
      await withDb((db) => db.asUser(anna.id, (tx) => tx.query("DELETE FROM gyms WHERE id = $1::uuid", [gymId])), url);
    });

    it("bez prihlásenia fitká nevydá", async () => {
      expect((await call("GET", "/gyms")).status).toBe(401);
    });

    it("zoznam obsahuje fitko s detailmi a prázdnym hodnotením", async () => {
      const res = await call("GET", "/gyms", { token: anna.token });
      const gym = res.body.gyms.find((g: Json) => g.id === gymId);
      expect(gym).toMatchObject({
        city: "Nitra",
        lat: 48.3,
        openingHours: "Nonstop",
        tags: ["Kardio"],
        photoUrls: [],
        rating: { stars: [0, 0, 0, 0, 0] },
        myStars: null,
      });
    });

    it("hodnotenie: súhrn vidia všetci, „moje“ len autor", async () => {
      let res = await call("PUT", `/gyms/${gymId}/review`, { token: anna.token, body: { stars: 5 } });
      expect(res.body).toMatchObject({ rating: { stars: [0, 0, 0, 0, 1] }, myStars: 5 });
      res = await call("GET", `/gyms/${gymId}`, { token: boris.token });
      expect(res.body).toMatchObject({ rating: { stars: [0, 0, 0, 0, 1] }, myStars: null });
      res = await call("PUT", `/gyms/${gymId}/review`, { token: boris.token, body: { stars: 2 } });
      expect(res.body.rating.stars).toEqual([0, 1, 0, 0, 1]);
      res = await call("DELETE", `/gyms/${gymId}/review`, { token: boris.token });
      expect(res.body).toMatchObject({ rating: { stars: [0, 0, 0, 0, 1] }, myStars: null });
    });

    it("neplatné hodnotenie a neznáme fitko", async () => {
      expect((await call("PUT", `/gyms/${gymId}/review`, { token: anna.token, body: { stars: 6 } })).status).toBe(400);
      const res = await call("PUT", "/gyms/00000000-0000-4000-8000-0000000000ff/review", {
        token: anna.token,
        body: { stars: 4 },
      });
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe("gym_not_found");
      expect((await call("GET", "/gyms/nie-je-uuid", { token: anna.token })).status).toBe(400);
    });

    it("priveľa hodnotení za minútu server odmietne", async () => {
      let last = 0;
      for (let i = 0; i < 31; i++) {
        last = (await call("PUT", `/gyms/${gymId}/review`, { token: boris.token, body: { stars: 1 + (i % 5) } })).status;
      }
      expect(last).toBe(429);
    });
  });
});
