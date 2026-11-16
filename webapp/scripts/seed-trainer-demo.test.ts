// Lokálne ukážkové dáta pre trénerskú zónu (len proti lokálnej databáze).
// Spustenie: SEED_DEMO=1 npx vitest run scripts/seed-trainer-demo.test.ts
// S SEED_TOKEN_FILE=cesta zapíše token relácie trénera (pre cookie rejnox_session).
import { writeFileSync } from "node:fs";
import { config } from "dotenv";
import { expect, it } from "vitest";
import { withDb } from "../src/server/db";
import { handleApi } from "../src/server/router";

config({ path: ".env.local", quiet: true });
const url = process.env.DATABASE_URL ?? "";
const isLocal = /@(localhost|127\.0\.0\.1)[:/]/.test(url);

async function call(method: string, path: string, token?: string, body?: unknown) {
  const headers: Record<string, string> = { "cf-connecting-ip": `seed-${Math.random()}` };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await handleApi(
    new Request(`http://localhost/api${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined }),
    path,
    { connect: (fn) => withDb(fn, url) },
  );
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : {} };
}

const today = () => new Date().toLocaleDateString("sv-SE", { timeZone: "Europe/Bratislava" });

it.skipIf(!process.env.SEED_DEMO || !isLocal)("ukážkové dáta trénera", async () => {
  const run = Math.random().toString(36).slice(2, 6);
  const reg = async (name: string, role: string) =>
    (await call("POST", "/auth/register", undefined, {
      email: `demo-${Math.random().toString(36).slice(2, 8)}-${run}@test.local`,
      password: `demo-${run}-heslo`,
      displayName: name,
      role,
    })).body;
  const coach = await reg("Marek Tréner", "trainer");
  expect(coach.token, JSON.stringify(coach)).toBeTruthy();
  const exercises = (await call("GET", "/exercises", coach.token)).body.exercises as { id: string }[];

  const people = [
    { name: "Jana Nováková", note: "redukcia, 3× týždenne" },
    { name: "Peter Kováč", note: "naberanie svalov" },
    { name: "Lucia Hrdá", note: "koleno – opatrne s drepmi" },
  ];
  for (const [index, p] of people.entries()) {
    const link = (await call("POST", "/clients", coach.token, p)).body;
    if (index === 2) continue; // bez appky
    const member = await reg(p.name, "member");
    const code = (await call("POST", `/clients/${link.id}/invite`, coach.token)).body.code;
    await call("POST", "/invites/accept", member.token, { code });

    for (let d = 20; d >= 0; d -= 2) {
      for (let s = 0; s < 3; s++) {
        const performedAt = new Date(Date.now() - d * 86_400_000).toISOString();
        await call("POST", `/clients/${link.id}/sets`, coach.token, {
          id: crypto.randomUUID(),
          exerciseId: exercises[s % exercises.length].id,
          reps: 8,
          weightKg: 40 + (20 - d) * 1.5 + s * 10,
          performedAt,
        });
      }
    }

    const items = [0, 1, 2, 3, 4, 5, 6].flatMap((day) => [
      { day, meal: "Raňajky", name: "Ovsená kaša s banánom", amount: "80 g", kcal: 420, proteinG: 15, carbsG: 70, fatG: 8 },
      { day, meal: "Obed", name: "Kuracie prsia, ryža, zelenina", amount: "150 g / 80 g", kcal: 640, proteinG: 48, carbsG: 75, fatG: 12 },
      { day, meal: "Olovrant", name: "Grécky jogurt s orechmi", amount: "200 g", kcal: 280, proteinG: 20, carbsG: 12, fatG: 16 },
      { day, meal: "Večera", name: "Losos so zemiakmi", amount: "120 g", kcal: 560, proteinG: 34, carbsG: 45, fatG: 24 },
    ]);
    const plan = (await call("POST", `/clients/${link.id}/meal-plans`, coach.token, {
      title: index === 0 ? "Redukcia – týždeň 1" : "Objem – základ",
      targets: { kcal: index === 0 ? 1900 : 2800, proteinG: 140 },
      items,
    })).body;
    await call("POST", `/clients/${link.id}/meal-plans/${plan.id}/send`, coach.token);
    const sent = (await call("GET", "/me/meal-plans", member.token)).body.mealPlans[0];
    // Klient odškrtol väčšinu jedál dnes.
    for (const item of sent.items.filter((i: { day: number }) => i.day === (new Date().getDay() + 6) % 7).slice(0, index === 0 ? 3 : 2)) {
      await call("PUT", `/me/meal-items/${item.id}/checks/${today()}`, member.token);
    }
  }
  if (process.env.SEED_TOKEN_FILE) writeFileSync(process.env.SEED_TOKEN_FILE, coach.token);
  expect(coach.token).toBeTruthy();
});
