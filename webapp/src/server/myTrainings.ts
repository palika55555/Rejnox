import { bookingById } from "./calendar";
import type { Db } from "./db";
import { HttpError } from "./errors";
import { requireUuid, type Body } from "./validate";

const DAY_MS = 24 * 60 * 60 * 1000;

/** Klient vidí tréningy na mesiac dopredu. */
export const UPCOMING_DAYS = 30;

export type MyTraining = {
  id: string;
  linkId: string;
  trainerName: string;
  startsAt: Date;
  endsAt: Date;
  status: string;
  inSlot: boolean;
  title: string | null;
  note: string | null;
  slotNote: string | null;
  /** Plán s cvikmi (rovnaký tvar ako /me/plans), ak ho tréner pripojil. */
  workout: unknown;
};

/** Najbližšie rezervované tréningy klienta u všetkých trénerov: čas, rozpis a plán. */
export function upcoming(db: Db, userId: string, now = new Date()): Promise<MyTraining[]> {
  return db.asUser(userId, (tx) =>
    tx.query<MyTraining>(
      `SELECT id::text, link_id::text AS "linkId", trainer_name AS "trainerName",
              starts_at AS "startsAt", ends_at AS "endsAt", status, in_slot AS "inSlot",
              title, note, slot_note AS "slotNote", workout
       FROM my_trainings($1::timestamptz, $2::timestamptz)
       WHERE ends_at > $1::timestamptz`,
      [now, new Date(now.getTime() + UPCOMING_DAYS * DAY_MS)],
    ),
  );
}

/** `workoutId: null` plán od tréningu odpojí. */
export function parseBookingPlan(body: Body): string | null {
  return body.workoutId === null || body.workoutId === undefined ? null : requireUuid(body.workoutId, "workoutId");
}

/** Tréner pripojí k tréningu plán klienta (aj k miestu, ktoré si klient rezervoval sám). */
export function setBookingPlan(db: Db, trainerId: string, bookingId: string, workoutId: string | null) {
  return db.asUser(trainerId, async (tx) => {
    const rows = await tx.query(
      `UPDATE bookings b SET workout_id = $3::uuid
       WHERE b.id = $1::uuid AND b.trainer_id = $2::uuid AND b.status <> 'cancelled'
         AND ($3::uuid IS NULL OR EXISTS (
           SELECT 1 FROM workouts w WHERE w.id = $3::uuid AND w.trainer_client_id = b.trainer_client_id
         ))
       RETURNING b.id`,
      [bookingId, trainerId, workoutId],
    );
    if (rows.length === 0) throw new HttpError(404, "not_found", "Tréning alebo plán sa nenašiel.");
    return bookingById(tx, bookingId);
  });
}
