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
  // Ako route.ts: router dostane cestu bez ?query.
  const response = await handleApi(request, new URL(request.url).pathname.replace(/^\/api/, ""), {
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

  describe("domovská obrazovka", () => {
    const squat = "00000000-0000-4000-8000-000000000001";
    const today = new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Bratislava" }).format(new Date());

    it("nový účet má všetko prázdne", async () => {
      const fresh = await register("novacik");
      const res = await call("GET", "/home", { token: fresh.token });
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        streakDays: 0,
        weeklyGoal: { done: 0, total: 3 },
        todayWorkout: null,
        personalRecord: null,
      });
    });

    it("dnešný plán od trénera, séria a rekord aj zo sérií od trénera", async () => {
      const coach = await register("domtrener", "trainer");
      const member = await register("domclen");
      let res = await call("POST", "/clients", { token: coach.token, body: { name: "Člen" } });
      const linkId = res.body.id as string;
      res = await call("POST", `/clients/${linkId}/invite`, { token: coach.token });
      await call("POST", "/invites/accept", { token: member.token, body: { code: res.body.code } });

      await call("POST", `/clients/${linkId}/workouts`, {
        token: coach.token,
        body: { title: "Zajtrajší", scheduledOn: "2099-01-01", exercises: [{ exerciseId: squat, sets: 1, reps: 1 }] },
      });
      await call("POST", `/clients/${linkId}/workouts`, {
        token: coach.token,
        body: { title: "Nohy dnes", scheduledOn: today, exercises: [{ exerciseId: squat, sets: 4, reps: 6, weightKg: 100 }] },
      });

      const now = new Date().toISOString();
      await call("POST", "/sets/sync", {
        token: member.token,
        body: { sets: [{ id: crypto.randomUUID(), exerciseId: squat, reps: 5, weightKg: 90, performedAt: now }] },
      });
      await call("POST", `/clients/${linkId}/sets`, {
        token: coach.token,
        body: { id: crypto.randomUUID(), exerciseId: squat, reps: 3, weightKg: 105 },
      });

      res = await call("GET", "/home", { token: member.token });
      expect(res.status).toBe(200);
      expect(res.body.streakDays).toBe(1);
      expect(res.body.weeklyGoal).toEqual({ done: 1, total: 3 });
      expect(res.body.todayWorkout).toMatchObject({ title: "Nohy dnes", trainerName: "domtrener" });
      expect(res.body.todayWorkout.exercises[0]).toMatchObject({ sets: 4, reps: 6, weightKg: 100 });
      expect(res.body.personalRecord).toMatchObject({ weightKg: 105, monthDeltaKg: 0, trend: [105] });

      // Tréner na svojej domovskej obrazovke série klienta nevidí ako svoje.
      res = await call("GET", "/home", { token: coach.token });
      expect(res.body.personalRecord).toBeNull();
      expect(res.body.streakDays).toBe(0);
    });

    it("bez prihlásenia nič", async () => {
      expect((await call("GET", "/home")).status).toBe(401);
    });
  });

  describe("progres", () => {
    const squat = "00000000-0000-4000-8000-000000000001";

    it("nový účet má prázdny prehľad s 12 týždňami", async () => {
      const fresh = await register("progresnovy");
      const res = await call("GET", "/progress", { token: fresh.token });
      expect(res.status).toBe(200);
      expect(res.body.totals).toEqual({ trainingDays: 0, sets: 0, volumeKg: 0 });
      expect(res.body.weeks).toHaveLength(12);
      expect(res.body.exercises).toEqual([]);
    });

    it("zo série spočíta objem, rekord a odhad maxima", async () => {
      const me = await register("progresclen");
      const now = new Date().toISOString();
      await call("POST", "/sets/sync", {
        token: me.token,
        body: {
          sets: [
            { id: crypto.randomUUID(), exerciseId: squat, reps: 5, weightKg: 90, performedAt: now },
            { id: crypto.randomUUID(), exerciseId: squat, reps: 3, weightKg: 100, performedAt: now },
          ],
        },
      });
      const res = await call("GET", "/progress", { token: me.token });
      expect(res.status).toBe(200);
      expect(res.body.totals).toEqual({ trainingDays: 1, sets: 2, volumeKg: 750 });
      expect(res.body.month).toMatchObject({ days: 1, sets: 2, volumeKg: 750 });
      expect(res.body.exercises[0]).toMatchObject({ exerciseId: squat, bestKg: 100, bestE1rmKg: 110, days: 1 });
      expect(res.body.muscles).toEqual([{ muscleGroup: "nohy", sets: 2 }]);
    });

    it("bez prihlásenia nič", async () => {
      expect((await call("GET", "/progress")).status).toBe(401);
    });
  });

  describe("kalendár trénera", () => {
    let coach: Account;
    let anna: Account;
    let boris: Account;
    let outsider: Account;
    let annaLink: string;
    let borisLink: string;

    const HOUR = 60 * 60 * 1000;
    // Zajtra o 10:00 UTC, aby testy nezáviseli od aktuálnej hodiny.
    const base = new Date(Math.ceil(Date.now() / (24 * HOUR)) * 24 * HOUR + 10 * HOUR);
    const at = (hours: number) => new Date(base.getTime() + hours * HOUR).toISOString();
    const range = `from=${encodeURIComponent(at(-48))}&to=${encodeURIComponent(at(7 * 24))}`;

    async function link(member: Account, name: string): Promise<string> {
      let res = await call("POST", "/clients", { token: coach.token, body: { name } });
      const linkId = res.body.id as string;
      res = await call("POST", `/clients/${linkId}/invite`, { token: coach.token });
      res = await call("POST", "/invites/accept", { token: member.token, body: { code: res.body.code } });
      expect(res.status).toBe(200);
      return linkId;
    }

    beforeAll(async () => {
      coach = await register("kalendar", "trainer");
      anna = await register("annak");
      boris = await register("borisk");
      outsider = await register("cudzik");
      annaLink = await link(anna, "Anna");
      borisLink = await link(boris, "Boris");
    });

    it("vypísaný termín: miesta, plná kapacita, jedno miesto na klienta", async () => {
      let res = await call("POST", "/calendar/slots", {
        token: coach.token,
        body: { startsAt: at(0), endsAt: at(1), capacity: 1, title: "Kruhový tréning" },
      });
      expect(res.status).toBe(201);
      const slotId = res.body.id as string;

      res = await call("POST", `/me/trainers/${annaLink}/bookings`, { token: anna.token, body: { slotId } });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ status: "confirmed", slotId, requestedByClient: true });
      expect(res.body.startsAt).toBe(at(0));

      res = await call("POST", `/me/trainers/${annaLink}/bookings`, { token: anna.token, body: { slotId } });
      expect(res.status).toBe(409);

      res = await call("POST", `/me/trainers/${borisLink}/bookings`, { token: boris.token, body: { slotId } });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe("slot_full");

      // Boris vidí obsadenosť, ale nie Annine meno.
      res = await call("GET", `/me/trainers/${borisLink}/calendar?${range}`, { token: boris.token });
      expect(res.status).toBe(200);
      expect(res.body.slots).toEqual([expect.objectContaining({ id: slotId, capacity: 1, taken: 1 })]);
      expect(JSON.stringify(res.body)).not.toContain("Anna");

      // Tréner vidí v termíne Annu.
      res = await call("GET", `/calendar?${range}`, { token: coach.token });
      expect(res.body.slots[0].bookings).toEqual([expect.objectContaining({ clientId: annaLink, clientName: "Anna" })]);

      // Zrušenie termínu zruší aj rezerváciu.
      expect((await call("DELETE", `/calendar/slots/${slotId}`, { token: coach.token })).status).toBe(204);
      res = await call("GET", `/me/trainers/${annaLink}/calendar?${range}`, { token: anna.token });
      expect(res.body).toMatchObject({ slots: [], bookings: [] });
    });

    it("žiadosť o tréning: tréner potvrdí, ďalšia žiadosť na ten čas neprejde", async () => {
      let res = await call("POST", `/me/trainers/${annaLink}/bookings`, {
        token: anna.token,
        body: { startsAt: at(24), endsAt: at(25), note: "Nohy" },
      });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ status: "requested", note: "Nohy" });
      const bookingId = res.body.id as string;

      // Klient si žiadosť sám potvrdiť nevie.
      expect((await call("POST", `/bookings/${bookingId}/confirm`, { token: anna.token })).status).toBe(403);

      res = await call("POST", `/bookings/${bookingId}/confirm`, { token: coach.token });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe("confirmed");

      res = await call("POST", `/me/trainers/${borisLink}/bookings`, {
        token: boris.token,
        body: { startsAt: at(24.5), endsAt: at(25.5) },
      });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe("time_taken");

      res = await call("GET", `/me/trainers/${borisLink}/calendar?${range}`, { token: boris.token });
      expect(res.body.busy).toEqual([{ startsAt: at(24), endsAt: at(25) }]);
      res = await call("GET", `/me/trainers/${annaLink}/calendar?${range}`, { token: anna.token });
      expect(res.body.busy).toEqual([]);
      expect(res.body.bookings).toEqual([expect.objectContaining({ id: bookingId, status: "confirmed" })]);

      // Klient zruší, čas sa uvoľní.
      expect((await call("POST", `/bookings/${bookingId}/cancel`, { token: anna.token })).status).toBe(204);
      res = await call("GET", `/me/trainers/${borisLink}/calendar?${range}`, { token: boris.token });
      expect(res.body.busy).toEqual([]);
    });

    it("tréner zapíše klientovi tréning s plánom, aj odcvičený dozadu", async () => {
      const exercises = (await call("GET", "/exercises", { token: coach.token })).body.exercises;
      let res = await call("POST", `/clients/${borisLink}/workouts`, {
        token: coach.token,
        body: { title: "Hrudník", exercises: [{ exerciseId: exercises[0].id, sets: 3, reps: 10 }] },
      });
      const planId = res.body.id as string;

      res = await call("POST", "/calendar/bookings", {
        token: coach.token,
        body: { clientId: borisLink, startsAt: at(48), endsAt: at(49), title: "Osobný tréning", workoutId: planId },
      });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        status: "confirmed",
        requestedByClient: false,
        clientName: "Boris",
        workout: { id: planId, title: "Hrudník" },
      });

      res = await call("POST", "/calendar/bookings", {
        token: coach.token,
        body: { clientId: annaLink, startsAt: at(-30), endsAt: at(-29) },
      });
      expect(res.status).toBe(201);

      // Cudzí plán k tréningu nepripojí.
      res = await call("POST", "/calendar/bookings", {
        token: coach.token,
        body: { clientId: annaLink, startsAt: at(72), endsAt: at(73), workoutId: planId },
      });
      expect(res.status).toBe(404);

      // Kolízia s iným potvrdeným tréningom.
      res = await call("POST", "/calendar/bookings", {
        token: coach.token,
        body: { clientId: annaLink, startsAt: at(48.5), endsAt: at(49.5) },
      });
      expect(res.body.error.code).toBe("time_taken");
    });

    it("voľné termíny: upozornenia klientom, rozpis tréningu a plán pre klienta", async () => {
      const unreadSlots = async (who: Account) =>
        ((await call("GET", "/notifications", { token: who.token })).body.notifications as Json[]).filter(
          (n) => !n.read && n.kind === "slot",
        );
      for (const who of [anna, boris]) await call("POST", "/notifications/read", { token: who.token, body: {} });

      // Nový termín → upozornenie každému klientovi, druhý sa zlúči do jedného.
      let res = await call("POST", "/calendar/slots", {
        token: coach.token,
        body: { startsAt: at(96), endsAt: at(97), capacity: 2, title: "Joga", note: "Strečing a core" },
      });
      const slotId = res.body.id as string;
      let slots = await unreadSlots(boris);
      expect(slots).toEqual([expect.objectContaining({ title: "Nový voľný termín", linkId: borisLink })]);
      expect(slots[0].body).toContain("Joga");
      await call("POST", "/calendar/slots", {
        token: coach.token,
        body: { startsAt: at(100), endsAt: at(101), title: "Kruh" },
      });
      slots = await unreadSlots(anna);
      expect(slots).toEqual([expect.objectContaining({ title: "Nové voľné termíny" })]);

      // Anna si rezervuje miesto a vidí ho v najbližších tréningoch aj s rozpisom.
      res = await call("POST", `/me/trainers/${annaLink}/bookings`, { token: anna.token, body: { slotId } });
      const bookingId = res.body.id as string;
      res = await call("GET", "/me/trainings", { token: anna.token });
      expect(res.status).toBe(200);
      const mine = (res.body.trainings as Json[]).find((t) => t.id === bookingId);
      expect(mine).toMatchObject({
        linkId: annaLink,
        title: "Joga",
        slotNote: "Strečing a core",
        inSlot: true,
        status: "confirmed",
        startsAt: at(96),
        workout: null,
      });

      // Tréner pripojí plán → klient ho vidí s cvikmi a dostane upozornenie.
      const exercises = (await call("GET", "/exercises", { token: coach.token })).body.exercises;
      res = await call("POST", `/clients/${annaLink}/workouts`, {
        token: coach.token,
        body: { title: "Mobilita", exercises: [{ exerciseId: exercises[0].id, sets: 2, reps: 12 }] },
      });
      const planId = res.body.id as string;
      res = await call("PUT", `/bookings/${bookingId}/plan`, { token: anna.token, body: { workoutId: planId } });
      expect(res.status).toBe(403);
      const borisPlan = (await call("POST", `/clients/${borisLink}/workouts`, {
        token: coach.token,
        body: { title: "Cudzí", exercises: [{ exerciseId: exercises[0].id, sets: 1, reps: 1 }] },
      })).body.id;
      res = await call("PUT", `/bookings/${bookingId}/plan`, { token: coach.token, body: { workoutId: borisPlan } });
      expect(res.status).toBe(404);
      res = await call("PUT", `/bookings/${bookingId}/plan`, { token: coach.token, body: { workoutId: planId } });
      expect(res.status).toBe(200);
      expect(res.body.workout).toEqual({ id: planId, title: "Mobilita" });
      res = await call("GET", "/me/trainings", { token: anna.token });
      const planned = (res.body.trainings as Json[]).find((t) => t.id === bookingId)!;
      expect(planned.workout).toMatchObject({ id: planId, title: "Mobilita", exercises: [{ sets: 2, reps: 12 }] });
      res = await call("GET", "/notifications", { token: anna.token });
      expect(res.body.notifications[0]).toMatchObject({ kind: "training", title: "Rozpis tréningu" });
      // Boris Annin tréning nevidí.
      res = await call("GET", "/me/trainings", { token: boris.token });
      expect(JSON.stringify(res.body)).not.toContain(bookingId);

      // Anna miesto zruší → Boris sa dozvie, že je voľné; Anna nie.
      for (const who of [anna, boris]) await call("POST", "/notifications/read", { token: who.token, body: {} });
      expect((await call("POST", `/bookings/${bookingId}/cancel`, { token: anna.token })).status).toBe(204);
      expect(await unreadSlots(boris)).toEqual([expect.objectContaining({ title: "Uvoľnilo sa miesto" })]);
      expect(await unreadSlots(anna)).toEqual([]);

      // Zrušenie celého termínu voľné miesto neponúka.
      res = await call("POST", `/me/trainers/${borisLink}/bookings`, { token: boris.token, body: { slotId } });
      expect(res.status).toBe(201);
      for (const who of [anna, boris]) await call("POST", "/notifications/read", { token: who.token, body: {} });
      expect((await call("DELETE", `/calendar/slots/${slotId}`, { token: coach.token })).status).toBe(204);
      expect(await unreadSlots(anna)).toEqual([]);
    });

    it("cudzí človek kalendár nevidí a nerezervuje", async () => {
      expect((await call("GET", `/me/trainers/${annaLink}/calendar?${range}`, { token: outsider.token })).status).toBe(404);
      const res = await call("POST", `/me/trainers/${annaLink}/bookings`, {
        token: outsider.token,
        body: { startsAt: at(80), endsAt: at(81) },
      });
      expect(res.status).toBe(404);
      expect((await call("GET", `/calendar?${range}`, { token: anna.token })).status).toBe(403);
    });

    it("neplatné časy a obdobie", async () => {
      let res = await call("POST", `/me/trainers/${annaLink}/bookings`, {
        token: anna.token,
        body: { startsAt: at(-48), endsAt: at(-47) },
      });
      expect(res.body.error.code).toBe("in_past");
      res = await call("POST", "/calendar/slots", {
        token: coach.token,
        body: { startsAt: at(100), endsAt: at(100.1), title: "Krátke" },
      });
      expect(res.body.error.code).toBe("invalid_length");
      res = await call("GET", `/calendar?from=${encodeURIComponent(at(0))}&to=${encodeURIComponent(at(24 * 90))}`, {
        token: coach.token,
      });
      expect(res.body.error.code).toBe("invalid_range");
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

    it("používateľ pridá fitko, upraví ho len autor", async () => {
      const boris = await register("emil");
      let res = await call("POST", "/gyms", {
        token: anna.token,
        body: { name: `Nové ${run}`, city: "Žilina", lat: 49.22, lng: 18.74, tags: ["Kardio"], website: "fit.sk" },
      });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ city: "Žilina", mine: true, website: "https://fit.sk/", photos: [], prices: [] });
      const newId = res.body.id as string;

      res = await call("GET", `/gyms/${newId}`, { token: boris.token });
      expect(res.body.mine).toBe(false);
      const edit = { name: "Prepísané", city: "Žilina", lat: 49.2, lng: 18.7 };
      res = await call("PUT", `/gyms/${newId}`, { token: boris.token, body: edit });
      expect(res.status).toBe(403);
      expect((await call("DELETE", `/gyms/${newId}`, { token: boris.token })).status).toBe(403);

      res = await call("PUT", `/gyms/${newId}`, { token: anna.token, body: edit });
      expect(res.body).toMatchObject({ name: "Prepísané", lat: 49.2, tags: [] });
      expect((await call("DELETE", `/gyms/${newId}`, { token: anna.token })).status).toBe(204);
      expect((await call("GET", `/gyms/${newId}`, { token: anna.token })).status).toBe(404);
      expect((await call("POST", "/gyms", { token: anna.token, body: { name: "X", city: "Y" } })).status).toBe(400);
    });

    it("fotky: nahrá ktokoľvek, zmaže len autor fotky", async () => {
      // Boris už vyčerpal limit zápisov v teste hodnotení.
      const boris = await register("cyril");
      const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
      const upload = (token: string, body: Uint8Array) =>
        handleApi(
          new Request(`http://localhost/api/gyms/${gymId}/photos`, {
            method: "POST",
            headers: { authorization: `Bearer ${token}`, "content-type": "image/jpeg", "cf-connecting-ip": freshIp() },
            body: body as BodyInit,
          }),
          `/gyms/${gymId}/photos`,
          { connect: (fn) => withDb(fn, url) },
        );
      let response = await upload(boris.token, jpeg);
      expect(response.status).toBe(201);
      const photo = (await response.json()).photos[0];
      expect(photo.mine).toBe(true);

      response = await upload(boris.token, new TextEncoder().encode("<svg/>"));
      expect(response.status).toBe(415);

      const raw = await handleApi(
        new Request(`http://localhost/api/gym-photos/${photo.id}`, {
          headers: { authorization: `Bearer ${anna.token}`, "cf-connecting-ip": freshIp() },
        }),
        `/gym-photos/${photo.id}`,
        { connect: (fn) => withDb(fn, url) },
      );
      expect(raw.headers.get("content-type")).toBe("image/jpeg");
      expect(new Uint8Array(await raw.arrayBuffer())).toEqual(jpeg);

      expect((await call("DELETE", `/gym-photos/${photo.id}`, { token: anna.token })).status).toBe(403);
      const res = await call("DELETE", `/gym-photos/${photo.id}`, { token: boris.token });
      expect(res.body.photos).toEqual([]);
    });

    it("cenník: pridá ktokoľvek, zmaže len autor položky", async () => {
      const boris = await register("dana");
      let res = await call("POST", `/gyms/${gymId}/prices`, {
        token: boris.token,
        body: { kind: "membership", title: "Mesačná", priceCents: 3900, period: "mesiac" },
      });
      expect(res.status).toBe(201);
      expect(res.body.prices).toEqual([
        expect.objectContaining({ kind: "membership", title: "Mesačná", priceCents: 3900, currency: "EUR", mine: true }),
      ]);
      const priceId = res.body.prices[0].id as string;
      expect((await call("DELETE", `/gym-prices/${priceId}`, { token: anna.token })).status).toBe(403);
      res = await call("DELETE", `/gym-prices/${priceId}`, { token: boris.token });
      expect(res.body.prices).toEqual([]);
    });
  });
});
