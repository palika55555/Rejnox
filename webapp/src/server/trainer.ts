import { sha256Hex } from "./crypto";
import type { Db, Tx } from "./db";
import { HttpError } from "./errors";
import {
  newInviteCode,
  normalizeInviteCode,
  optionalText,
  requireInt,
  requireUuid,
  requireWeight,
  type Body,
} from "./validate";

const notFound = () => new HttpError(404, "not_found", "Klient sa nenašiel.");

/** Cvik v pláne tak, ako ho posiela tréner. */
export type PlanExercise = { exerciseId: string; sets: number; reps: number; weightKg: number | null; note: string | null };

export function parsePlanExercise(json: unknown): PlanExercise {
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    throw new HttpError(400, "invalid_exercises", "Neplatný cvik.");
  }
  const body = json as Body;
  return {
    exerciseId: requireUuid(body.exerciseId, "exerciseId"),
    sets: requireInt(body.sets, "sets", 1, 20),
    reps: requireInt(body.reps, "reps", 1, 1000),
    weightKg: body.weightKg === undefined || body.weightKg === null ? null : requireWeight(body.weightKg),
    note: optionalText(body, "note", 200),
  };
}

const clientColumns = `
  id::text, client_name AS name, note, status::text,
  client_user_id IS NOT NULL AS "hasAccount",
  invite_expires_at AS "inviteExpiresAt", created_at AS "createdAt"`;

// ---------------------------------------------------------------- tréner

export function listClients(db: Db, trainerId: string) {
  return db.asUser(trainerId, (tx) =>
    tx.query(
      `SELECT ${clientColumns} FROM trainer_clients
       WHERE trainer_id = $1::uuid
       ORDER BY status = 'ended', lower(client_name)`,
      [trainerId],
    ),
  );
}

export function addClient(db: Db, trainerId: string, name: string, note: string | null) {
  return db.asUser(trainerId, async (tx) => {
    const [row] = await tx.query(
      `INSERT INTO trainer_clients (trainer_id, client_name, note)
       VALUES ($1::uuid, $2, $3)
       RETURNING ${clientColumns}`,
      [trainerId, name, note],
    );
    return row;
  });
}

/** Detail klienta: údaje, plány s cvikmi a posledné série. */
export function clientDetail(db: Db, trainerId: string, clientId: string) {
  return db.asUser(trainerId, async (tx) => {
    const [client] = await tx.query(
      `SELECT ${clientColumns} FROM trainer_clients WHERE id = $1::uuid AND trainer_id = $2::uuid`,
      [clientId, trainerId],
    );
    if (!client) throw notFound();
    return {
      ...client,
      workouts: await workouts(tx, "w.trainer_client_id = $1::uuid", [clientId]),
      sets: await recentSets(tx, clientId),
    };
  });
}

/** Vydá nový pozývací kód (platí 7 dní). Kód sa vráti len raz, v databáze je len jeho odtlačok. */
export function invite(db: Db, trainerId: string, clientId: string) {
  return db.asUser(trainerId, async (tx) => {
    const code = newInviteCode();
    const [row] = await tx.query<{ invite_expires_at: Date }>(
      `UPDATE trainer_clients
       SET status = 'invited', invite_token_hash = $1, invite_expires_at = now() + interval '7 days'
       WHERE id = $2::uuid AND trainer_id = $3::uuid
         AND client_user_id IS NULL AND status IN ('record_only', 'invited')
       RETURNING invite_expires_at`,
      [await sha256Hex(normalizeInviteCode(code)), clientId, trainerId],
    );
    if (!row) throw new HttpError(409, "cannot_invite", "Tohto klienta už pozvať nejde.");
    return { code, expiresAt: row.invite_expires_at.toISOString() };
  });
}

/** Ukončí spoluprácu (tréner aj klient). Tréner potom stratí prístup. */
export async function endLink(db: Db, userId: string, linkId: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const rows = await tx.query(
      `UPDATE trainer_clients
       SET status = 'ended', invite_token_hash = NULL, invite_expires_at = NULL
       WHERE id = $1::uuid AND status <> 'ended'
       RETURNING id`,
      [linkId],
    );
    if (rows.length === 0) throw notFound();
  });
}

/** Zmazať sa dá len klient bez účtu (história klienta s účtom ostáva). */
export async function deleteClient(db: Db, trainerId: string, clientId: string): Promise<void> {
  await db.asUser(trainerId, async (tx) => {
    const rows = await tx.query("DELETE FROM trainer_clients WHERE id = $1::uuid RETURNING id", [clientId]);
    if (rows.length === 0) {
      throw new HttpError(409, "cannot_delete", "Klienta s účtom nejde zmazať, spoluprácu môžeš len ukončiť.");
    }
  });
}

export function addWorkout(
  db: Db,
  trainerId: string,
  clientId: string,
  input: { title: string; scheduledOn: string | null; exercises: PlanExercise[] },
) {
  return db.asUser(trainerId, async (tx) => {
    const [created] = await tx.query<{ id: string }>(
      `INSERT INTO workouts (trainer_client_id, title, scheduled_on, created_by)
       SELECT t.id, $1, $2::date, $3::uuid FROM trainer_clients t
       WHERE t.id = $4::uuid AND t.trainer_id = $3::uuid AND t.status <> 'ended'
       RETURNING id::text`,
      [input.title, input.scheduledOn, trainerId, clientId],
    );
    if (!created) throw notFound();
    for (const [position, e] of input.exercises.entries()) {
      await tx.query(
        `INSERT INTO workout_exercises (workout_id, exercise_id, position, sets, reps, weight_kg, note)
         VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7)`,
        [created.id, e.exerciseId, position, e.sets, e.reps, e.weightKg, e.note],
      );
    }
    const [workout] = await workouts(tx, "w.id = $1::uuid", [created.id]);
    return workout;
  });
}

export async function deleteWorkout(db: Db, trainerId: string, clientId: string, workoutId: string): Promise<void> {
  await db.asUser(trainerId, async (tx) => {
    const rows = await tx.query(
      "DELETE FROM workouts WHERE id = $1::uuid AND trainer_client_id = $2::uuid RETURNING id",
      [workoutId, clientId],
    );
    if (rows.length === 0) throw notFound();
  });
}

/** Tréner zapíše sériu klientovi. ID z appky = bez duplikátov. */
export function logSet(
  db: Db,
  trainerId: string,
  clientId: string,
  input: { id: string; exerciseId: string; reps: number; weightKg: number; performedAt: Date | null },
) {
  return db.asUser(trainerId, async (tx) => {
    const rows = await tx.query(
      `INSERT INTO set_logs (id, trainer_client_id, exercise_id, reps, weight_kg, performed_at, logged_by)
       SELECT $1::uuid, t.id, $2::uuid, $3, $4, coalesce($5::timestamptz, now()), $6::uuid
       FROM trainer_clients t
       WHERE t.id = $7::uuid AND t.trainer_id = $6::uuid AND t.status <> 'ended'
       ON CONFLICT (id) DO NOTHING
       RETURNING id`,
      [input.id, input.exerciseId, input.reps, input.weightKg, input.performedAt, trainerId, clientId],
    );
    if (rows.length === 0) {
      // Buď už existuje (opakované odoslanie), alebo klient nepatrí trénerovi.
      const exists = await tx.query("SELECT 1 FROM set_logs WHERE id = $1::uuid AND trainer_client_id = $2::uuid", [
        input.id,
        clientId,
      ]);
      if (exists.length === 0) throw notFound();
    }
    return { id: input.id };
  });
}

// ---------------------------------------------------------------- klient

/** Klient zadá kód od trénera. */
export function acceptInvite(db: Db, userId: string, code: string) {
  return db.asUser(userId, async (tx) => {
    let linkId: string;
    try {
      const [row] = await tx.query<{ id: string }>("SELECT accept_client_invite($1)::text AS id", [await sha256Hex(code)]);
      linkId = row.id;
    } catch (error) {
      if (error instanceof Error && error.message.includes("invite invalid")) {
        throw new HttpError(404, "invalid_code", "Kód neplatí alebo už vypršal.");
      }
      throw error;
    }
    const trainers = await myTrainersTx(tx, userId);
    return trainers.find((t) => t.linkId === linkId);
  });
}

export function myTrainers(db: Db, userId: string) {
  return db.asUser(userId, (tx) => myTrainersTx(tx, userId));
}

/** Plány od všetkých mojich trénerov. */
export function myPlans(db: Db, userId: string) {
  return db.asUser(userId, (tx) =>
    workouts(tx, "w.trainer_client_id IN (SELECT id FROM trainer_clients WHERE client_user_id = $1::uuid)", [userId]),
  );
}

// ---------------------------------------------------------------- pomocné

function myTrainersTx(tx: Tx, userId: string) {
  return tx.query<{ linkId: string; trainerName: string; status: string; createdAt: Date }>(
    `SELECT t.id::text AS "linkId", p.display_name AS "trainerName",
            t.status::text AS status, t.created_at AS "createdAt"
     FROM trainer_clients t
     JOIN public_profiles p ON p.id = t.trainer_id
     WHERE t.client_user_id = $1::uuid
     ORDER BY t.status = 'ended', t.created_at DESC`,
    [userId],
  );
}

/** Plány s cvikmi. `where` je pevný SQL text, hodnoty idú len cez parametre. */
function workouts(tx: Tx, where: string, params: unknown[]) {
  return tx.query(
    `SELECT w.id::text, w.title, to_char(w.scheduled_on, 'YYYY-MM-DD') AS "scheduledOn",
            w.created_at AS "createdAt", p.display_name AS "trainerName",
            coalesce(json_agg(json_build_object(
              'exerciseId', we.exercise_id, 'name', e.name,
              'muscleGroup', e.muscle_group, 'sets', we.sets, 'reps', we.reps,
              'weightKg', we.weight_kg::float8, 'note', we.note
            ) ORDER BY we.position) FILTER (WHERE we.id IS NOT NULL), '[]') AS exercises
     FROM workouts w
     JOIN trainer_clients t ON t.id = w.trainer_client_id
     JOIN public_profiles p ON p.id = t.trainer_id
     LEFT JOIN workout_exercises we ON we.workout_id = w.id
     LEFT JOIN exercises e ON e.id = we.exercise_id
     WHERE ${where}
     GROUP BY w.id, p.display_name
     ORDER BY w.scheduled_on DESC NULLS LAST, w.created_at DESC
     LIMIT 50`,
    params,
  );
}

function recentSets(tx: Tx, clientId: string) {
  return tx.query(
    `SELECT s.id::text, s.exercise_id::text AS "exerciseId", e.name,
            s.reps, s.weight_kg::float8 AS "weightKg", s.performed_at AS "performedAt"
     FROM set_logs s JOIN exercises e ON e.id = s.exercise_id
     WHERE s.trainer_client_id = $1::uuid
     ORDER BY s.performed_at DESC
     LIMIT 100`,
    [clientId],
  );
}
