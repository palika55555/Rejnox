import type { Db, Tx } from "./db";
import { planOn } from "./trainer";

/** Rejnox je slovenská appka: „dnes“ a týždeň sa rátajú podľa slovenského času. */
export const ZONE = "Europe/Bratislava";

/** Koľko tréningových dní za týždeň je cieľ (zatiaľ pevne, neskôr nastavenie v profile). */
export const WEEKLY_GOAL_DAYS = 3;

/** Bodov v grafe osobného rekordu. */
const TREND_POINTS = 8;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Posun dátumu „YYYY-MM-DD“ o počet dní. */
export function shift(day: string, days: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + days * DAY_MS).toISOString().slice(0, 10);
}

/** Koľko dní za sebou používateľ cvičil, končiac dnes alebo včera (dnešok sa ešte dá stihnúť). */
export function streakDays(trainingDays: string[], today: string): number {
  const days = new Set(trainingDays);
  let day = days.has(today) ? today : shift(today, -1);
  let count = 0;
  while (days.has(day)) {
    count++;
    day = shift(day, -1);
  }
  return count;
}

/** Počet dní s tréningom od pondelka tohto týždňa po dnešok. */
export function weekDays(trainingDays: string[], today: string): number {
  const weekday = (new Date(`${today}T00:00:00Z`).getUTCDay() + 6) % 7; // pondelok = 0
  const monday = shift(today, -weekday);
  return new Set(trainingDays.filter((d) => d >= monday && d <= today)).size;
}

/**
 * Zlepšenie rekordu za posledný mesiac: oproti najlepšiemu výkonu spred mesiaca,
 * a keď staršie série nie sú, oproti prvému tréningovému dňu v tomto mesiaci.
 */
export function monthDelta(bestKg: number, bestBeforeKg: number | null, monthDailyBests: number[]): number {
  const base = bestBeforeKg ?? monthDailyBests[0] ?? bestKg;
  return Math.max(0, bestKg - base);
}

export type HomeOverview = {
  streakDays: number;
  weeklyGoal: { done: number; total: number };
  todayWorkout: Awaited<ReturnType<typeof planOn>>;
  personalRecord: { exercise: string; weightKg: number; monthDeltaKg: number; trend: number[] } | null;
};

/**
 * Série používateľa: jeho vlastné aj tie, čo mu zapísal tréner.
 * Tréner cez RLS vidí aj série klientov, preto výslovný filter na vlastníka.
 */
export const MY_SETS = `
  SELECT s.exercise_id, s.reps, s.weight_kg::float8 AS kg, (s.performed_at AT TIME ZONE $2)::date AS day
  FROM set_logs s
  LEFT JOIN trainer_clients tc ON tc.id = s.trainer_client_id
  WHERE coalesce(s.user_id, tc.client_user_id) = $1::uuid`;

async function personalRecord(tx: Tx, userId: string, today: string): Promise<HomeOverview["personalRecord"]> {
  // Rekord = cvik s najťažšou sériou (pri zhode ten, čo bol odcvičený neskôr).
  const [best] = await tx.query<{ exerciseId: string; name: string; kg: number }>(
    `WITH mine AS (${MY_SETS})
     SELECT m.exercise_id::text AS "exerciseId", e.name, max(m.kg) AS kg
     FROM mine m JOIN exercises e ON e.id = m.exercise_id
     GROUP BY m.exercise_id, e.name
     ORDER BY max(m.kg) DESC, max(m.day) DESC
     LIMIT 1`,
    [userId, ZONE],
  );
  if (!best) return null;

  const monthStart = shift(today, -30);
  const daily = await tx.query<{ day: string; kg: number }>(
    `WITH mine AS (${MY_SETS})
     SELECT to_char(day, 'YYYY-MM-DD') AS day, max(kg) AS kg
     FROM mine WHERE exercise_id = $3::uuid
     GROUP BY day ORDER BY day`,
    [userId, ZONE, best.exerciseId],
  );
  const before = daily.filter((d) => d.day < monthStart).map((d) => d.kg);
  const inMonth = daily.filter((d) => d.day >= monthStart).map((d) => d.kg);
  return {
    exercise: best.name,
    weightKg: best.kg,
    monthDeltaKg: monthDelta(best.kg, before.length ? Math.max(...before) : null, inMonth),
    trend: daily.slice(-TREND_POINTS).map((d) => d.kg),
  };
}

/** Všetko pre domovskú obrazovku (karta Dnes). */
export function overview(db: Db, userId: string): Promise<HomeOverview> {
  return db.asUser(userId, async (tx) => {
    const [{ today }] = await tx.query<{ today: string }>(
      "SELECT to_char((now() AT TIME ZONE $1)::date, 'YYYY-MM-DD') AS today",
      [ZONE],
    );
    const rows = await tx.query<{ day: string }>(
      `WITH mine AS (${MY_SETS})
       SELECT DISTINCT to_char(day, 'YYYY-MM-DD') AS day FROM mine
       WHERE day > $3::date`,
      [userId, ZONE, shift(today, -400)],
    );
    const days = rows.map((r) => r.day);
    return {
      streakDays: streakDays(days, today),
      weeklyGoal: { done: weekDays(days, today), total: WEEKLY_GOAL_DAYS },
      todayWorkout: await planOn(tx, userId, today),
      personalRecord: await personalRecord(tx, userId, today),
    };
  });
}
