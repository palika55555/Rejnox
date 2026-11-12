import type { Db } from "./db";
import { HttpError } from "./errors";
import { isUuid, parseTime, type Body } from "./validate";

export const MAX_SETS_PER_SYNC = 200;

/** Jedna odcvičená séria tak, ako ju posiela appka. */
export type SetInput = { id: string; exerciseId: string; reps: number; weightKg: number; performedAt: Date };

/**
 * Výsledok synchronizácie: prijaté ID (aj tie, čo už na serveri boli)
 * a odmietnuté ID s dôvodom, aby ich appka prestala posielať.
 */
export type SyncResult = { accepted: string[]; rejected: { id: string; reason: string }[] };

const DAY_MS = 24 * 60 * 60 * 1000;

/** Rozparsuje telo požiadavky. Chybné položky nevyhodia celú dávku, len sa označia ako odmietnuté. */
export function parseSets(body: Body, now = new Date()): { sets: SetInput[]; rejected: Map<string, string> } {
  const raw = body.sets;
  if (!Array.isArray(raw)) throw new HttpError(400, "invalid_sets", "Chýba zoznam sérií.");
  if (raw.length > MAX_SETS_PER_SYNC) {
    throw new HttpError(413, "too_many_sets", `Naraz sa dá poslať najviac ${MAX_SETS_PER_SYNC} sérií.`);
  }
  const sets: SetInput[] = [];
  const rejected = new Map<string, string>();
  for (const item of raw as unknown[]) {
    if (typeof item !== "object" || item === null || Array.isArray(item)) continue;
    const { id, exerciseId, reps, weightKg } = item as Body;
    if (!isUuid(id)) continue;
    const performedAt = parseTime((item as Body).performedAt);

    let reason: string | undefined;
    if (!isUuid(exerciseId)) reason = "invalid_exercise";
    else if (typeof reps !== "number" || !Number.isInteger(reps) || reps < 1 || reps > 1000) reason = "invalid_reps";
    else if (typeof weightKg !== "number" || !Number.isFinite(weightKg) || weightKg < 0 || weightKg > 1000)
      reason = "invalid_weight";
    else if (
      performedAt === null ||
      performedAt.getTime() > now.getTime() + DAY_MS ||
      performedAt.getTime() < now.getTime() - 366 * DAY_MS
    )
      reason = "invalid_time";

    if (reason) {
      rejected.set(id, reason);
      continue;
    }
    sets.push({ id, exerciseId: exerciseId as string, reps: reps as number, weightKg: weightKg as number, performedAt: performedAt! });
  }
  return { sets, rejected };
}

export function exercises(db: Db, userId: string) {
  return db.asUser(userId, (tx) =>
    tx.query<{ id: string; name: string; muscleGroup: string | null }>(
      'SELECT id::text, name, muscle_group AS "muscleGroup" FROM exercises ORDER BY name',
    ),
  );
}

/** Uloží série. Opakované poslanie tej istej série nič nezdvojí. */
export function syncSets(db: Db, userId: string, sets: SetInput[], rejected: Map<string, string>): Promise<SyncResult> {
  return db.asUser(userId, async (tx) => {
    const accepted: string[] = [];
    if (sets.length > 0) {
      const known = await tx.query<{ id: string }>("SELECT id::text FROM exercises WHERE id = ANY($1::uuid[])", [
        [...new Set(sets.map((s) => s.exerciseId))],
      ]);
      const knownIds = new Set(known.map((r) => r.id));
      for (const s of sets) {
        if (!knownIds.has(s.exerciseId)) {
          rejected.set(s.id, "unknown_exercise");
          continue;
        }
        await tx.query(
          `INSERT INTO set_logs (id, user_id, exercise_id, reps, weight_kg, performed_at, logged_by)
           VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $2::uuid)
           ON CONFLICT (id) DO NOTHING`,
          [s.id, userId, s.exerciseId, s.reps, s.weightKg, s.performedAt],
        );
        accepted.push(s.id);
      }
    }
    return { accepted, rejected: [...rejected].map(([id, reason]) => ({ id, reason })) };
  });
}
