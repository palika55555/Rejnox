import type { Db, Tx } from "./db";
import { HttpError } from "./errors";
import { optionalDate, optionalText, requireInt, requireText, requireUuid, type Body } from "./validate";

/** Najviac jedál v jednom jedálničku (7 dní × ~10 jedál/položiek). */
export const MAX_ITEMS = 120;

export const DAY_NAMES = ["Pondelok", "Utorok", "Streda", "Štvrtok", "Piatok", "Sobota", "Nedeľa"] as const;

export type MealItemInput = {
  /** ID existujúcej položky (pri úprave ostane, aj s odškrtnutiami klienta). */
  id: string | null;
  day: number;
  meal: string;
  name: string;
  amount: string | null;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
  note: string | null;
};

export type Targets = { kcal: number | null; proteinG: number | null; carbsG: number | null; fatG: number | null };

export type MealPlanInput = {
  title: string;
  note: string | null;
  startsOn: string | null;
  targets: Targets;
  items: MealItemInput[];
};

export type MealItem = Omit<MealItemInput, "id"> & { id: string; position: number };

export type MealPlan = {
  id: string;
  clientId: string;
  title: string;
  note: string | null;
  startsOn: string | null;
  targets: Targets;
  sentAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  trainerName: string;
  items: MealItem[];
};

export type MealPlanSummary = Omit<MealPlan, "items"> & { itemCount: number; avgKcal: number };

const invalid = (field: string, message: string) => new HttpError(400, `invalid_${field}`, message);
const notFound = () => new HttpError(404, "not_found", "Jedálniček sa nenašiel.");

/** Gramy makroživín: nezáporné číslo s jedným desatinným miestom. */
function grams(value: unknown, field: string, max: number): number {
  if (value === undefined || value === null) return 0;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > max) {
    throw invalid(field, `Zadaj 0 až ${max} g.`);
  }
  return Math.round(value * 10) / 10;
}

function optionalInt(value: unknown, field: string, min: number, max: number): number | null {
  return value === undefined || value === null || value === "" ? null : requireInt(value, field, min, max);
}

function parseItem(json: unknown): MealItemInput {
  if (typeof json !== "object" || json === null || Array.isArray(json)) throw invalid("items", "Neplatné jedlo.");
  const body = json as Body;
  return {
    id: body.id === undefined || body.id === null ? null : requireUuid(body.id, "item_id"),
    day: requireInt(body.day, "day", 0, 6),
    meal: requireText(body, "meal", 40, "Názov jedla dňa"),
    name: requireText(body, "name", 120, "Jedlo"),
    amount: optionalText(body, "amount", 60),
    kcal: requireInt(body.kcal, "kcal", 0, 5000),
    proteinG: grams(body.proteinG, "proteinG", 500),
    carbsG: grams(body.carbsG, "carbsG", 1000),
    fatG: grams(body.fatG, "fatG", 500),
    note: optionalText(body, "note", 200),
  };
}

/** Jedálniček z tela požiadavky (trénerská web appka aj mobil). */
export function parseMealPlan(body: Body): MealPlanInput {
  const raw = body.items ?? [];
  if (!Array.isArray(raw) || raw.length > MAX_ITEMS) {
    throw invalid("items", `Jedálniček môže mať najviac ${MAX_ITEMS} jedál.`);
  }
  const items = raw.map(parseItem);
  const ids = items.flatMap((i) => (i.id ? [i.id] : []));
  if (new Set(ids).size !== ids.length) throw invalid("items", "Jedlo je v jedálničku dvakrát.");
  const t = (body.targets ?? {}) as Body;
  return {
    title: requireText(body, "title", 120, "Názov"),
    note: optionalText(body, "note", 1000),
    startsOn: optionalDate(body, "startsOn"),
    targets: {
      kcal: optionalInt(t.kcal, "kcal_target", 500, 10000),
      proteinG: optionalInt(t.proteinG, "protein_target", 0, 1000),
      carbsG: optionalInt(t.carbsG, "carbs_target", 0, 2000),
      fatG: optionalInt(t.fatG, "fat_target", 0, 1000),
    },
    items,
  };
}

/** Súčet kalórií a makier za jeden deň jedálnička. */
export function dayTotals(items: Pick<MealItem, "day" | "kcal" | "proteinG" | "carbsG" | "fatG">[], day: number) {
  const sum = { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 };
  for (const i of items) {
    if (i.day !== day) continue;
    sum.kcal += i.kcal;
    sum.proteinG += i.proteinG;
    sum.carbsG += i.carbsG;
    sum.fatG += i.fatG;
  }
  const r1 = (n: number) => Math.round(n * 10) / 10;
  return { kcal: sum.kcal, proteinG: r1(sum.proteinG), carbsG: r1(sum.carbsG), fatG: r1(sum.fatG) };
}

// ---------------------------------------------------------------- SQL

const planColumns = `
  m.id::text, m.trainer_client_id::text AS "clientId", m.title, m.note,
  to_char(m.starts_on, 'YYYY-MM-DD') AS "startsOn",
  json_build_object('kcal', m.kcal_target, 'proteinG', m.protein_g_target,
                    'carbsG', m.carbs_g_target, 'fatG', m.fat_g_target) AS targets,
  m.sent_at AS "sentAt", m.created_at AS "createdAt", m.updated_at AS "updatedAt",
  p.display_name AS "trainerName"`;

const planFrom = `
  FROM meal_plans m
  JOIN trainer_clients t ON t.id = m.trainer_client_id
  JOIN public_profiles p ON p.id = t.trainer_id`;

async function itemsOf(tx: Tx, planIds: string[]): Promise<Map<string, MealItem[]>> {
  const rows = await tx.query<MealItem & { planId: string }>(
    `SELECT id::text, meal_plan_id::text AS "planId", day, position, meal, name, amount, kcal,
            protein_g::float8 AS "proteinG", carbs_g::float8 AS "carbsG", fat_g::float8 AS "fatG", note
     FROM meal_plan_items WHERE meal_plan_id = ANY($1::uuid[])
     ORDER BY day, position`,
    [planIds],
  );
  const byPlan = new Map<string, MealItem[]>();
  for (const { planId, ...item } of rows) byPlan.set(planId, [...(byPlan.get(planId) ?? []), item]);
  return byPlan;
}

async function loadPlan(tx: Tx, planId: string, clientId: string): Promise<MealPlan> {
  const [plan] = await tx.query<Omit<MealPlan, "items">>(
    `SELECT ${planColumns} ${planFrom} WHERE m.id = $1::uuid AND m.trainer_client_id = $2::uuid`,
    [planId, clientId],
  );
  if (!plan) throw notFound();
  return { ...plan, items: (await itemsOf(tx, [planId])).get(planId) ?? [] };
}

/** Uloží položky: zachová tie s ID, zmaže chýbajúce, pridá nové. */
async function saveItems(tx: Tx, planId: string, items: MealItemInput[]): Promise<void> {
  const keep = items.flatMap((i) => (i.id ? [i.id] : []));
  await tx.query("DELETE FROM meal_plan_items WHERE meal_plan_id = $1::uuid AND NOT (id = ANY($2::uuid[]))", [
    planId,
    keep,
  ]);
  const positions = new Map<number, number>();
  for (const item of items) {
    const position = positions.get(item.day) ?? 0;
    positions.set(item.day, position + 1);
    const values = [
      item.day, position, item.meal, item.name, item.amount, item.kcal,
      item.proteinG, item.carbsG, item.fatG, item.note, planId,
    ];
    if (item.id) {
      const updated = await tx.query(
        `UPDATE meal_plan_items SET day = $1, position = $2, meal = $3, name = $4, amount = $5, kcal = $6,
                protein_g = $7, carbs_g = $8, fat_g = $9, note = $10
         WHERE meal_plan_id = $11::uuid AND id = $12::uuid RETURNING id`,
        [...values, item.id],
      );
      if (updated.length === 1) continue;
    }
    await tx.query(
      `INSERT INTO meal_plan_items (day, position, meal, name, amount, kcal, protein_g, carbs_g, fat_g, note, meal_plan_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::uuid)`,
      values,
    );
  }
}

// ---------------------------------------------------------------- tréner

/** Jedálničky klienta (bez položiek, so súhrnom). */
export function listForClient(db: Db, trainerId: string, clientId: string): Promise<MealPlanSummary[]> {
  return db.asUser(trainerId, async (tx) => {
    const owned = await tx.query("SELECT 1 FROM trainer_clients WHERE id = $1::uuid AND trainer_id = $2::uuid", [
      clientId,
      trainerId,
    ]);
    if (owned.length === 0) throw new HttpError(404, "not_found", "Klient sa nenašiel.");
    return tx.query<MealPlanSummary>(
      `SELECT ${planColumns},
              (SELECT count(*)::int FROM meal_plan_items i WHERE i.meal_plan_id = m.id) AS "itemCount",
              coalesce((SELECT round(sum(i.kcal) / greatest(count(DISTINCT i.day), 1))::int
                        FROM meal_plan_items i WHERE i.meal_plan_id = m.id), 0) AS "avgKcal"
       ${planFrom}
       WHERE m.trainer_client_id = $1::uuid
       ORDER BY m.created_at DESC
       LIMIT 50`,
      [clientId],
    );
  });
}

export function getForTrainer(db: Db, trainerId: string, clientId: string, planId: string): Promise<MealPlan> {
  return db.asUser(trainerId, (tx) => loadPlan(tx, planId, clientId));
}

export function create(db: Db, trainerId: string, clientId: string, input: MealPlanInput): Promise<MealPlan> {
  return db.asUser(trainerId, async (tx) => {
    const [created] = await tx.query<{ id: string }>(
      `INSERT INTO meal_plans (trainer_client_id, title, note, starts_on, kcal_target, protein_g_target,
                               carbs_g_target, fat_g_target, created_by)
       SELECT t.id, $1, $2, $3::date, $4, $5, $6, $7, $8::uuid FROM trainer_clients t
       WHERE t.id = $9::uuid AND t.trainer_id = $8::uuid AND t.status <> 'ended'
       RETURNING id::text`,
      [
        input.title, input.note, input.startsOn, input.targets.kcal, input.targets.proteinG,
        input.targets.carbsG, input.targets.fatG, trainerId, clientId,
      ],
    );
    if (!created) throw new HttpError(404, "not_found", "Klient sa nenašiel.");
    await saveItems(tx, created.id, input.items.map((i) => ({ ...i, id: null })));
    return loadPlan(tx, created.id, clientId);
  });
}

export function update(
  db: Db,
  trainerId: string,
  clientId: string,
  planId: string,
  input: MealPlanInput,
): Promise<MealPlan> {
  return db.asUser(trainerId, async (tx) => {
    const rows = await tx.query(
      `UPDATE meal_plans SET title = $1, note = $2, starts_on = $3::date, kcal_target = $4,
              protein_g_target = $5, carbs_g_target = $6, fat_g_target = $7, updated_at = now()
       WHERE id = $8::uuid AND trainer_client_id = $9::uuid
       RETURNING id`,
      [
        input.title, input.note, input.startsOn, input.targets.kcal, input.targets.proteinG,
        input.targets.carbsG, input.targets.fatG, planId, clientId,
      ],
    );
    if (rows.length === 0) throw notFound();
    await saveItems(tx, planId, input.items);
    return loadPlan(tx, planId, clientId);
  });
}

/** Odošle jedálniček klientovi do appky (znova odoslaný = nové upozornenie). */
export function send(db: Db, trainerId: string, clientId: string, planId: string): Promise<MealPlan> {
  return db.asUser(trainerId, async (tx) => {
    const [link] = await tx.query<{ hasAccount: boolean; items: number }>(
      `SELECT t.client_user_id IS NOT NULL AND t.status = 'linked' AS "hasAccount",
              (SELECT count(*)::int FROM meal_plan_items i WHERE i.meal_plan_id = m.id) AS items
       FROM meal_plans m JOIN trainer_clients t ON t.id = m.trainer_client_id
       WHERE m.id = $1::uuid AND m.trainer_client_id = $2::uuid`,
      [planId, clientId],
    );
    if (!link) throw notFound();
    if (!link.hasAccount) {
      throw new HttpError(409, "client_not_linked", "Klient ešte nemá prepojený účet. Pošli mu najprv pozvánku.");
    }
    if (link.items === 0) throw new HttpError(409, "empty_plan", "Jedálniček je prázdny, pridaj aspoň jedno jedlo.");
    await tx.query("UPDATE meal_plans SET sent_at = now(), updated_at = now() WHERE id = $1::uuid", [planId]);
    return loadPlan(tx, planId, clientId);
  });
}

export async function remove(db: Db, trainerId: string, clientId: string, planId: string): Promise<void> {
  await db.asUser(trainerId, async (tx) => {
    const rows = await tx.query(
      "DELETE FROM meal_plans WHERE id = $1::uuid AND trainer_client_id = $2::uuid RETURNING id",
      [planId, clientId],
    );
    if (rows.length === 0) throw notFound();
  });
}

/** Skopíruje jedálniček inému (alebo tomu istému) klientovi ako nový koncept. */
export function copy(
  db: Db,
  trainerId: string,
  clientId: string,
  planId: string,
  targetClientId: string,
): Promise<MealPlan> {
  return db.asUser(trainerId, async (tx) => {
    const source = await loadPlan(tx, planId, clientId);
    const title = targetClientId === clientId ? `${source.title} (kópia)`.slice(0, 120) : source.title;
    const [created] = await tx.query<{ id: string }>(
      `INSERT INTO meal_plans (trainer_client_id, title, note, starts_on, kcal_target, protein_g_target,
                               carbs_g_target, fat_g_target, created_by)
       SELECT t.id, $1, $2, NULL, $3, $4, $5, $6, $7::uuid FROM trainer_clients t
       WHERE t.id = $8::uuid AND t.trainer_id = $7::uuid AND t.status <> 'ended'
       RETURNING id::text`,
      [
        title, source.note, source.targets.kcal, source.targets.proteinG, source.targets.carbsG,
        source.targets.fatG, trainerId, targetClientId,
      ],
    );
    if (!created) throw new HttpError(404, "not_found", "Klient sa nenašiel.");
    await saveItems(tx, created.id, source.items.map((i) => ({ ...i, id: null })));
    return loadPlan(tx, created.id, targetClientId);
  });
}

// ---------------------------------------------------------------- klient

export type ClientMealPlan = MealPlan & { checks: { itemId: string; eatenOn: string }[] };

/** Odoslané jedálničky od mojich trénerov, najnovší prvý, s odškrtnutiami za 14 dní. */
export function myMealPlans(db: Db, userId: string): Promise<ClientMealPlan[]> {
  return db.asUser(userId, async (tx) => {
    const plans = await tx.query<Omit<MealPlan, "items">>(
      `SELECT ${planColumns} ${planFrom}
       WHERE t.client_user_id = $1::uuid AND m.sent_at IS NOT NULL
       ORDER BY m.sent_at DESC
       LIMIT 10`,
      [userId],
    );
    const ids = plans.map((p) => p.id);
    const items = await itemsOf(tx, ids);
    const checks = await tx.query<{ planId: string; itemId: string; eatenOn: string }>(
      `SELECT i.meal_plan_id::text AS "planId", c.item_id::text AS "itemId",
              to_char(c.eaten_on, 'YYYY-MM-DD') AS "eatenOn"
       FROM meal_item_checks c JOIN meal_plan_items i ON i.id = c.item_id
       WHERE i.meal_plan_id = ANY($1::uuid[]) AND c.eaten_on >= current_date - 14`,
      [ids],
    );
    return plans.map((p) => ({
      ...p,
      items: items.get(p.id) ?? [],
      checks: checks.filter((c) => c.planId === p.id).map(({ itemId, eatenOn }) => ({ itemId, eatenOn })),
    }));
  });
}

/** Odškrtne (alebo zruší) zjedené jedlo v daný deň. */
export async function setChecked(
  db: Db,
  userId: string,
  itemId: string,
  eatenOn: string,
  eaten: boolean,
): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const [ok] = await tx.query<{ ok: boolean; near: boolean }>(
      "SELECT can_check_meal($1::uuid) AS ok, abs($2::date - current_date) <= 7 AS near",
      [itemId, eatenOn],
    );
    if (!ok.ok) throw new HttpError(404, "not_found", "Jedlo sa nenašlo.");
    if (!ok.near) throw invalid("eatenOn", "Odškrtnúť sa dá len jedlo z posledného týždňa.");
    if (eaten) {
      await tx.query(
        "INSERT INTO meal_item_checks (item_id, eaten_on) VALUES ($1::uuid, $2::date) ON CONFLICT DO NOTHING",
        [itemId, eatenOn],
      );
    } else {
      await tx.query("DELETE FROM meal_item_checks WHERE item_id = $1::uuid AND eaten_on = $2::date", [
        itemId,
        eatenOn,
      ]);
    }
  });
}
