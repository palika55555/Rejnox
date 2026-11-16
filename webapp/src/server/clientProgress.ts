import type { Db } from "./db";
import { HttpError } from "./errors";
import { ZONE, shift } from "./home";
import { summarize, type DayRow, type Progress } from "./progress";

/** Koľko posledných dní ukazuje dodržiavanie jedálnička. */
export const NUTRITION_DAYS = 14;

const E1RM_SQL = "CASE WHEN s.reps = 1 THEN s.weight_kg WHEN s.reps <= 12 THEN s.weight_kg * (1 + s.reps / 30.0) END";

/** Pondelok = 0 … nedeľa = 6 pre deň „YYYY-MM-DD“. */
export function weekday(day: string): number {
  return (new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7;
}

export type SentPlan = { id: string; sentDay: string };
export type PlanItem = { id: string; planId: string; day: number; kcal: number; proteinG: number };
export type Check = { itemId: string; eatenOn: string };

export type NutritionDay = {
  day: string;
  planId: string | null;
  plannedMeals: number;
  eatenMeals: number;
  plannedKcal: number;
  eatenKcal: number;
  eatenProteinG: number;
};

export type Nutrition = {
  days: NutritionDay[];
  /** Podiel zjedených jedál zo všetkých naplánovaných za obdobie (0–100), null = nebol plán. */
  adherencePct: number | null;
  /** Kedy klient naposledy niečo odškrtol. */
  lastCheckDay: string | null;
};

/**
 * Dodržiavanie jedálnička po dňoch. V daný deň platí najnovší jedálniček odoslaný
 * najneskôr v ten deň; naplánované sú jeho jedlá pre daný deň v týždni.
 */
export function nutrition(plans: SentPlan[], items: PlanItem[], checks: Check[], today: string): Nutrition {
  const sorted = [...plans].sort((a, b) => b.sentDay.localeCompare(a.sentDay));
  const checked = new Set(checks.map((c) => `${c.itemId}|${c.eatenOn}`));
  const days: NutritionDay[] = [];
  for (let i = NUTRITION_DAYS - 1; i >= 0; i--) {
    const day = shift(today, -i);
    const plan = sorted.find((p) => p.sentDay <= day);
    const planned = plan ? items.filter((it) => it.planId === plan.id && it.day === weekday(day)) : [];
    const eaten = planned.filter((it) => checked.has(`${it.id}|${day}`));
    days.push({
      day,
      planId: plan?.id ?? null,
      plannedMeals: planned.length,
      eatenMeals: eaten.length,
      plannedKcal: planned.reduce((s, it) => s + it.kcal, 0),
      eatenKcal: eaten.reduce((s, it) => s + it.kcal, 0),
      eatenProteinG: Math.round(eaten.reduce((s, it) => s + it.proteinG, 0) * 10) / 10,
    });
  }
  const planned = days.reduce((s, d) => s + d.plannedMeals, 0);
  const eaten = days.reduce((s, d) => s + d.eatenMeals, 0);
  const lastCheckDay = checks.reduce<string | null>((m, c) => (m === null || c.eatenOn > m ? c.eatenOn : m), null);
  return {
    days,
    adherencePct: planned === 0 ? null : Math.round((eaten / planned) * 100),
    lastCheckDay,
  };
}

export type ClientProgress = { training: Progress; nutrition: Nutrition };

/** Progres klienta pre trénera: série v rámci spolupráce a dodržiavanie jedálnička. */
export function clientProgress(db: Db, trainerId: string, clientId: string): Promise<ClientProgress> {
  return db.asUser(trainerId, async (tx) => {
    const owned = await tx.query("SELECT 1 FROM trainer_clients WHERE id = $1::uuid AND trainer_id = $2::uuid", [
      clientId,
      trainerId,
    ]);
    if (owned.length === 0) throw new HttpError(404, "not_found", "Klient sa nenašiel.");

    const [{ today }] = await tx.query<{ today: string }>(
      "SELECT to_char((now() AT TIME ZONE $1)::date, 'YYYY-MM-DD') AS today",
      [ZONE],
    );
    const rows = await tx.query<DayRow>(
      `SELECT to_char((s.performed_at AT TIME ZONE $2)::date, 'YYYY-MM-DD') AS day,
              s.exercise_id::text AS "exerciseId", e.name, e.muscle_group AS "muscleGroup",
              count(*)::int AS sets, sum(s.reps * s.weight_kg)::float8 AS "volumeKg",
              max(s.weight_kg)::float8 AS "bestKg", max(${E1RM_SQL})::float8 AS "e1rmKg"
       FROM set_logs s JOIN exercises e ON e.id = s.exercise_id
       WHERE s.trainer_client_id = $1::uuid
       GROUP BY 1, s.exercise_id, e.name, e.muscle_group
       ORDER BY 1, e.name`,
      [clientId, ZONE],
    );

    const plans = await tx.query<SentPlan>(
      `SELECT id::text, to_char((sent_at AT TIME ZONE $2)::date, 'YYYY-MM-DD') AS "sentDay"
       FROM meal_plans WHERE trainer_client_id = $1::uuid AND sent_at IS NOT NULL`,
      [clientId, ZONE],
    );
    const ids = plans.map((p) => p.id);
    const items = await tx.query<PlanItem>(
      `SELECT id::text, meal_plan_id::text AS "planId", day, kcal, protein_g::float8 AS "proteinG"
       FROM meal_plan_items WHERE meal_plan_id = ANY($1::uuid[])`,
      [ids],
    );
    const checks = await tx.query<Check>(
      `SELECT c.item_id::text AS "itemId", to_char(c.eaten_on, 'YYYY-MM-DD') AS "eatenOn"
       FROM meal_item_checks c JOIN meal_plan_items i ON i.id = c.item_id
       WHERE i.meal_plan_id = ANY($1::uuid[]) AND c.eaten_on >= $2::date`,
      [ids, shift(today, -(NUTRITION_DAYS - 1))],
    );

    return { training: summarize(rows, today), nutrition: nutrition(plans, items, checks, today) };
  });
}
