import type { Db, Tx } from "./db";
import { HttpError, pgCode } from "./errors";
import { optionalText, parseTime, requireInt, requireText, requireUuid, type Body } from "./validate";

const MINUTE_MS = 60 * 1000;
const DAY_MS = 24 * 60 * MINUTE_MS;

/** Tréning trvá 15 minút až 8 hodín. */
const MIN_LENGTH_MS = 15 * MINUTE_MS;
const MAX_LENGTH_MS = 8 * 60 * MINUTE_MS;
/** Najďalej dopredu sa dá plánovať rok, tréner zapíše tréning až 90 dní dozadu. */
const MAX_AHEAD_MS = 366 * DAY_MS;
const MAX_BACK_MS = 90 * DAY_MS;
/** Najdlhšie obdobie, ktoré kalendár vráti naraz. */
const MAX_RANGE_MS = 62 * DAY_MS;

export type TimeRange = { start: Date; end: Date };

// --------------------------------------------------------------- vstupy

function requireTime(value: unknown, field: string): Date {
  const time = parseTime(value);
  if (!time) throw new HttpError(400, `invalid_${field}`, "Neplatný čas.");
  return time;
}

/** Obdobie kalendára z ?from=…&to=… (ISO časy). */
export function parseRange(url: URL): TimeRange {
  const start = requireTime(url.searchParams.get("from"), "from");
  const end = requireTime(url.searchParams.get("to"), "to");
  const length = end.getTime() - start.getTime();
  if (length <= 0 || length > MAX_RANGE_MS) {
    throw new HttpError(400, "invalid_range", "Kalendár sa dá načítať najviac na 62 dní.");
  }
  return { start, end };
}

/** Čas tréningu z tela požiadavky. `allowPast` = tréner zapisuje odcvičený tréning. */
export function parseTimes(body: Body, { allowPast }: { allowPast: boolean }, now = new Date()): TimeRange {
  const start = requireTime(body.startsAt, "startsAt");
  const end = requireTime(body.endsAt, "endsAt");
  const length = end.getTime() - start.getTime();
  if (length < MIN_LENGTH_MS || length > MAX_LENGTH_MS) {
    throw new HttpError(400, "invalid_length", "Tréning musí trvať 15 minút až 8 hodín.");
  }
  const earliest = now.getTime() - (allowPast ? MAX_BACK_MS : 0);
  if (start.getTime() < earliest) {
    throw new HttpError(400, "in_past", allowPast ? "Zapísať sa dá najviac 90 dní dozadu." : "Termín už prebehol.");
  }
  if (start.getTime() > now.getTime() + MAX_AHEAD_MS) {
    throw new HttpError(400, "too_far", "Plánovať sa dá najviac rok dopredu.");
  }
  return { start, end };
}

export type SlotInput = TimeRange & { capacity: number; title: string; note: string | null };

export function parseSlot(body: Body, now = new Date()): SlotInput {
  return {
    ...parseTimes(body, { allowPast: false }, now),
    capacity: body.capacity === undefined ? 1 : requireInt(body.capacity, "capacity", 1, 50),
    title: requireText(body, "title", 80, "Názov"),
    note: optionalText(body, "note", 500),
  };
}

const optionalUuid = (body: Body, field: string) =>
  body[field] === undefined || body[field] === null ? null : requireUuid(body[field], field);

/** Tréner zapisuje klientovi tréning: buď miesto vo vypísanom termíne, alebo vlastný čas. */
export type TrainerBookingInput = {
  clientId: string;
  slotId: string | null;
  times: TimeRange | null;
  title: string | null;
  note: string | null;
  workoutId: string | null;
};

export function parseTrainerBooking(body: Body, now = new Date()): TrainerBookingInput {
  const slotId = optionalUuid(body, "slotId");
  return {
    clientId: requireUuid(body.clientId, "clientId"),
    slotId,
    times: slotId ? null : parseTimes(body, { allowPast: true }, now),
    title: optionalText(body, "title", 80),
    note: optionalText(body, "note", 500),
    workoutId: optionalUuid(body, "workoutId"),
  };
}

/** Klient: miesto vo vypísanom termíne, alebo žiadosť o vlastný čas. */
export type ClientBookingInput = { slotId: string | null; times: TimeRange | null; note: string | null };

export function parseClientBooking(body: Body, now = new Date()): ClientBookingInput {
  const slotId = optionalUuid(body, "slotId");
  return {
    slotId,
    times: slotId ? null : parseTimes(body, { allowPast: false }, now),
    note: optionalText(body, "note", 500),
  };
}

// ---------------------------------------------------------- chyby z DB

/** Pravidlá kalendára strážia triggery v databáze; tu sa ich chyby prekladajú pre používateľa. */
async function guarded<T>(body: () => Promise<T>): Promise<T> {
  try {
    return await body();
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    const code = pgCode(error);
    if (message.includes("slot full")) throw new HttpError(409, "slot_full", "Termín je už plný.");
    if (message.includes("time unavailable") || code === "23P01") {
      throw new HttpError(409, "time_taken", "V tomto čase už má tréner iný tréning.");
    }
    if (message.includes("in past")) throw new HttpError(400, "in_past", "Termín už prebehol.");
    if (message.includes("capacity below")) {
      throw new HttpError(409, "capacity_too_low", "Miest nemôže byť menej, ako je rezervácií.");
    }
    if (message.includes("no active link") || message.includes("slot not found")) {
      throw new HttpError(404, "not_found", "Termín sa nenašiel.");
    }
    if (code === "23505") throw new HttpError(409, "already_booked", "V tomto termíne už je miesto rezervované.");
    throw error;
  }
}

const notFound = () => new HttpError(404, "not_found", "Termín sa nenašiel.");

// --------------------------------------------------------------- dopyty

const bookingColumns = `
  b.id::text, lower(b.during) AS "startsAt", upper(b.during) AS "endsAt",
  b.status::text, b.title, b.note, b.slot_id::text AS "slotId",
  t.id::text AS "clientId", t.client_name AS "clientName",
  (b.created_by IS DISTINCT FROM b.trainer_id) AS "requestedByClient",
  CASE WHEN w.id IS NULL THEN NULL ELSE json_build_object('id', w.id::text, 'title', w.title) END AS workout`;

function bookingsWhere(tx: Tx, where: string, params: unknown[]) {
  return tx.query(
    `SELECT ${bookingColumns}
     FROM bookings b
     JOIN trainer_clients t ON t.id = b.trainer_client_id
     LEFT JOIN workouts w ON w.id = b.workout_id
     WHERE ${where}
     ORDER BY lower(b.during)
     LIMIT 500`,
    params,
  );
}

export async function bookingById(tx: Tx, bookingId: string) {
  const [booking] = await bookingsWhere(tx, "b.id = $1::uuid", [bookingId]);
  if (!booking) throw notFound();
  return booking;
}

// ---------------------------------------------------------------- tréner

/** Celý kalendár trénera: vypísané termíny s klientmi a osobné tréningy (aj žiadosti). */
export function trainerCalendar(db: Db, trainerId: string, range: TimeRange) {
  return db.asUser(trainerId, async (tx) => {
    const slots = await tx.query(
      `SELECT s.id::text, lower(s.during) AS "startsAt", upper(s.during) AS "endsAt",
              s.title, s.note, s.capacity
       FROM trainer_slots s
       WHERE s.trainer_id = $1::uuid AND s.during && tstzrange($2::timestamptz, $3::timestamptz)
       ORDER BY lower(s.during)`,
      [trainerId, range.start, range.end],
    );
    const bookings = await bookingsWhere(
      tx,
      `b.trainer_id = $1::uuid AND b.status <> 'cancelled'
       AND b.during && tstzrange($2::timestamptz, $3::timestamptz)`,
      [trainerId, range.start, range.end],
    );
    return {
      slots: slots.map((s) => ({ ...s, bookings: bookings.filter((b) => b.slotId === s.id) })),
      bookings: bookings.filter((b) => b.slotId === null),
    };
  });
}

export function addSlot(db: Db, trainerId: string, input: SlotInput) {
  return db.asUser(trainerId, (tx) =>
    guarded(async () => {
      const [slot] = await tx.query(
        `INSERT INTO trainer_slots (trainer_id, during, capacity, title, note)
         VALUES ($1::uuid, tstzrange($2::timestamptz, $3::timestamptz), $4, $5, $6)
         RETURNING id::text, lower(during) AS "startsAt", upper(during) AS "endsAt", title, note, capacity`,
        [trainerId, input.start, input.end, input.capacity, input.title, input.note],
      );
      return { ...slot, bookings: [] };
    }),
  );
}

/** Zruší termín: rezervácie v ňom sa zrušia (klienti ich uvidia ako zrušené) a termín zmizne. */
export async function deleteSlot(db: Db, trainerId: string, slotId: string): Promise<void> {
  await db.asUser(trainerId, async (tx) => {
    await tx.query(
      `UPDATE bookings SET status = 'cancelled'
       WHERE slot_id = $1::uuid AND trainer_id = $2::uuid AND status <> 'cancelled'`,
      [slotId, trainerId],
    );
    const rows = await tx.query("DELETE FROM trainer_slots WHERE id = $1::uuid RETURNING id", [slotId]);
    if (rows.length === 0) throw notFound();
  });
}

/** Tréner zapíše klientovi tréning, rovno potvrdený. */
export function addTrainerBooking(db: Db, trainerId: string, input: TrainerBookingInput) {
  return db.asUser(trainerId, (tx) =>
    guarded(async () => {
      if (input.workoutId) {
        const plan = await tx.query("SELECT 1 FROM workouts WHERE id = $1::uuid AND trainer_client_id = $2::uuid", [
          input.workoutId,
          input.clientId,
        ]);
        if (plan.length === 0) throw new HttpError(404, "plan_not_found", "Plán sa nenašiel.");
      }
      // Čas termínu doplní trigger podľa slot_id.
      const [created] = await tx.query<{ id: string }>(
        `INSERT INTO bookings (trainer_id, trainer_client_id, during, slot_id, status, title, note, workout_id)
         SELECT $1::uuid, t.id,
                CASE WHEN $3::timestamptz IS NULL THEN NULL ELSE tstzrange($3::timestamptz, $4::timestamptz) END,
                $5::uuid, 'confirmed', $6, $7, $8::uuid
         FROM trainer_clients t
         WHERE t.id = $2::uuid AND t.trainer_id = $1::uuid AND t.status <> 'ended'
         RETURNING id::text`,
        [
          trainerId,
          input.clientId,
          input.times?.start ?? null,
          input.times?.end ?? null,
          input.slotId,
          input.title,
          input.note,
          input.workoutId,
        ],
      );
      if (!created) throw new HttpError(404, "not_found", "Klient sa nenašiel.");
      return bookingById(tx, created.id);
    }),
  );
}

/** Tréner potvrdí žiadosť klienta. */
export function confirmBooking(db: Db, trainerId: string, bookingId: string) {
  return db.asUser(trainerId, (tx) =>
    guarded(async () => {
      const rows = await tx.query(
        `UPDATE bookings SET status = 'confirmed'
         WHERE id = $1::uuid AND trainer_id = $2::uuid AND status = 'requested'
         RETURNING id`,
        [bookingId, trainerId],
      );
      if (rows.length === 0) throw notFound();
      return bookingById(tx, bookingId);
    }),
  );
}

// ------------------------------------------------------- tréner aj klient

/** Zrušenie (aj odmietnutie žiadosti). Kto čo smie, stráži databáza. */
export async function cancelBooking(db: Db, userId: string, bookingId: string): Promise<void> {
  await db.asUser(userId, async (tx) => {
    const rows = await tx.query(
      "UPDATE bookings SET status = 'cancelled' WHERE id = $1::uuid AND status <> 'cancelled' RETURNING id",
      [bookingId],
    );
    if (rows.length === 0) throw notFound();
  });
}

// ---------------------------------------------------------------- klient

type MyLink = { trainerId: string; trainerName: string };

async function activeLink(tx: Tx, userId: string, linkId: string): Promise<MyLink> {
  const [link] = await tx.query<MyLink>(
    `SELECT t.trainer_id::text AS "trainerId", p.display_name AS "trainerName"
     FROM trainer_clients t JOIN public_profiles p ON p.id = t.trainer_id
     WHERE t.id = $1::uuid AND t.client_user_id = $2::uuid AND t.status = 'linked'`,
    [linkId, userId],
  );
  if (!link) throw new HttpError(404, "not_found", "Tréner sa nenašiel.");
  return link;
}

/**
 * Kalendár trénera pre klienta: vypísané termíny s voľnými miestami, obsadené
 * časy (bez mien) a moje rezervácie.
 */
export function clientCalendar(db: Db, userId: string, linkId: string, range: TimeRange) {
  return db.asUser(userId, async (tx) => {
    const link = await activeLink(tx, userId, linkId);
    const schedule = await tx.query<{
      kind: string;
      slot_id: string | null;
      starts_at: Date;
      ends_at: Date;
      title: string | null;
      note: string | null;
      capacity: number | null;
      taken: number | null;
    }>("SELECT * FROM trainer_schedule($1::uuid, $2::timestamptz, $3::timestamptz)", [
      link.trainerId,
      range.start,
      range.end,
    ]);
    const mine = await bookingsWhere(
      tx,
      `b.trainer_client_id = $1::uuid AND b.status <> 'cancelled'
       AND b.during && tstzrange($2::timestamptz, $3::timestamptz)`,
      [linkId, range.start, range.end],
    );
    return {
      trainerName: link.trainerName,
      slots: schedule
        .filter((s) => s.kind === "slot")
        .map((s) => ({
          id: s.slot_id,
          startsAt: s.starts_at,
          endsAt: s.ends_at,
          title: s.title,
          note: s.note,
          capacity: s.capacity,
          taken: s.taken,
        })),
      // Moje potvrdené tréningy sú v "bookings", obsadené časy sú len tie ostatné.
      busy: schedule
        .filter((s) => s.kind === "busy")
        .filter(
          (s) =>
            !mine.some(
              (b) =>
                b.slotId === null &&
                b.status === "confirmed" &&
                (b.startsAt as Date).getTime() === s.starts_at.getTime() &&
                (b.endsAt as Date).getTime() === s.ends_at.getTime(),
            ),
        )
        .map((s) => ({ startsAt: s.starts_at, endsAt: s.ends_at })),
      bookings: mine,
    };
  });
}

/** Klient si rezervuje miesto v termíne alebo požiada o vlastný čas. */
export function addClientBooking(db: Db, userId: string, linkId: string, input: ClientBookingInput) {
  return db.asUser(userId, (tx) =>
    guarded(async () => {
      const link = await activeLink(tx, userId, linkId);
      const [created] = await tx.query<{ id: string }>(
        `INSERT INTO bookings (trainer_id, trainer_client_id, during, slot_id, status, note)
         VALUES ($1::uuid, $2::uuid,
                 CASE WHEN $3::timestamptz IS NULL THEN NULL ELSE tstzrange($3::timestamptz, $4::timestamptz) END,
                 $5::uuid, $6::booking_status, $7)
         RETURNING id::text`,
        [
          link.trainerId,
          linkId,
          input.times?.start ?? null,
          input.times?.end ?? null,
          input.slotId,
          input.slotId ? "confirmed" : "requested",
          input.note,
        ],
      );
      return bookingById(tx, created.id);
    }),
  );
}
