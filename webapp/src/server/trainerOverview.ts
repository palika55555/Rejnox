import { nutrition, type Check, type PlanItem } from "./clientProgress";
import type { Db } from "./db";
import { ZONE } from "./home";

export type ClientOverview = {
  id: string;
  name: string;
  note: string | null;
  status: string;
  hasAccount: boolean;
  lastTrainingDay: string | null;
  setsLast30: number;
  latestPlan: { id: string; title: string; sentAt: Date | null } | null;
  draftPlans: number;
  adherencePct: number | null;
  lastCheckDay: string | null;
};

type ClientRow = Omit<ClientOverview, "latestPlan" | "adherencePct" | "lastCheckDay"> & {
  latestPlanId: string | null;
  latestPlanTitle: string | null;
  latestPlanSentAt: Date | null;
};

/** Prehľad všetkých klientov trénera pre úvodnú obrazovku trénerskej zóny. */
export function trainerOverview(db: Db, trainerId: string): Promise<{ today: string; clients: ClientOverview[] }> {
  return db.asUser(trainerId, async (tx) => {
    const [{ today }] = await tx.query<{ today: string }>(
      "SELECT to_char((now() AT TIME ZONE $1)::date, 'YYYY-MM-DD') AS today",
      [ZONE],
    );
    const rows = await tx.query<ClientRow>(
      `SELECT t.id::text, t.client_name AS name, t.note, t.status::text,
              t.client_user_id IS NOT NULL AS "hasAccount",
              (SELECT to_char(max((s.performed_at AT TIME ZONE $2)::date), 'YYYY-MM-DD')
                 FROM set_logs s WHERE s.trainer_client_id = t.id) AS "lastTrainingDay",
              (SELECT count(*)::int FROM set_logs s
                WHERE s.trainer_client_id = t.id AND s.performed_at > now() - interval '30 days') AS "setsLast30",
              lp.id::text AS "latestPlanId", lp.title AS "latestPlanTitle", lp.sent_at AS "latestPlanSentAt",
              (SELECT count(*)::int FROM meal_plans m WHERE m.trainer_client_id = t.id AND m.sent_at IS NULL)
                AS "draftPlans"
       FROM trainer_clients t
       LEFT JOIN LATERAL (
         SELECT m.id, m.title, m.sent_at FROM meal_plans m
         WHERE m.trainer_client_id = t.id ORDER BY m.updated_at DESC LIMIT 1
       ) lp ON true
       WHERE t.trainer_id = $1::uuid
       ORDER BY t.status = 'ended', lower(t.client_name)`,
      [trainerId, ZONE],
    );

    const plans = await tx.query<{ id: string; clientId: string; sentDay: string }>(
      `SELECT m.id::text, m.trainer_client_id::text AS "clientId",
              to_char((m.sent_at AT TIME ZONE $2)::date, 'YYYY-MM-DD') AS "sentDay"
       FROM meal_plans m JOIN trainer_clients t ON t.id = m.trainer_client_id
       WHERE t.trainer_id = $1::uuid AND m.sent_at IS NOT NULL`,
      [trainerId, ZONE],
    );
    const ids = plans.map((p) => p.id);
    const items = await tx.query<PlanItem>(
      `SELECT id::text, meal_plan_id::text AS "planId", day, kcal, protein_g::float8 AS "proteinG"
       FROM meal_plan_items WHERE meal_plan_id = ANY($1::uuid[])`,
      [ids],
    );
    const checks = await tx.query<Check & { planId: string }>(
      `SELECT c.item_id::text AS "itemId", i.meal_plan_id::text AS "planId",
              to_char(c.eaten_on, 'YYYY-MM-DD') AS "eatenOn"
       FROM meal_item_checks c JOIN meal_plan_items i ON i.id = c.item_id
       WHERE i.meal_plan_id = ANY($1::uuid[]) AND c.eaten_on >= current_date - 14`,
      [ids],
    );

    const clients = rows.map(({ latestPlanId, latestPlanTitle, latestPlanSentAt, ...row }) => {
      const mine = plans.filter((p) => p.clientId === row.id);
      const planIds = new Set(mine.map((p) => p.id));
      const n = nutrition(
        mine,
        items.filter((i) => planIds.has(i.planId)),
        checks.filter((c) => planIds.has(c.planId)),
        today,
      );
      return {
        ...row,
        latestPlan: latestPlanId ? { id: latestPlanId, title: latestPlanTitle ?? "", sentAt: latestPlanSentAt } : null,
        adherencePct: n.adherencePct,
        lastCheckDay: n.lastCheckDay,
      };
    });
    return { today, clients };
  });
}
