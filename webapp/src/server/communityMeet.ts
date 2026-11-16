import type { Db, Tx } from "./db";
import { HttpError } from "./errors";
import { ZONE } from "./home";
import { notFound } from "./communityPosts";

// Komunita – parťáci na tréning (partner_sessions), udalosti, výzvy
// a týždenný rebríček aktivity. Pravidlá prístupu sú v 019_community.

const LIST_LIMIT = 50;
const LEADERBOARD_LIMIT = 50;

const ended = (what: string) => new HttpError(409, "already_ended", `${what} už skončil(a).`);

// ---------------------------------------------------------------- parťáci

export type BuddyRequest = {
  id: string;
  hostId: string;
  hostName: string;
  startsAt: Date;
  place: string | null;
  focus: string | null;
  note: string | null;
  members: number;
  joined: boolean;
  mine: boolean;
};

export type BuddyDraft = { startsAt: Date; place: string; focus: string | null; note: string | null };

const BUDDY_COLUMNS = `
  s.id::text, s.host_id::text AS "hostId", coalesce(pp.display_name, 'Používateľ') AS "hostName",
  s.starts_at AS "startsAt", s.place, s.focus, s.note,
  (SELECT count(*)::int FROM partner_session_members m WHERE m.session_id = s.id) AS members,
  EXISTS (SELECT 1 FROM partner_session_members m WHERE m.session_id = s.id AND m.user_id = $1::uuid) AS joined,
  s.host_id = $1::uuid AS mine`;

async function buddyById(tx: Tx, userId: string, id: string): Promise<BuddyRequest> {
  const [row] = await tx.query<BuddyRequest>(
    `SELECT ${BUDDY_COLUMNS} FROM partner_sessions s LEFT JOIN public_profiles pp ON pp.id = s.host_id
     WHERE s.id = $2::uuid`,
    [userId, id],
  );
  if (!row) throw notFound("Tréning");
  return row;
}

/** Nadchádzajúce spoločné tréningy (aj tie, čo začali pred chvíľou). */
export function buddies(db: Db, userId: string): Promise<BuddyRequest[]> {
  return db.asUser(userId, (tx) =>
    tx.query<BuddyRequest>(
      `SELECT ${BUDDY_COLUMNS} FROM partner_sessions s LEFT JOIN public_profiles pp ON pp.id = s.host_id
       WHERE s.starts_at > now() - interval '2 hours'
       ORDER BY s.starts_at, s.id LIMIT ${LIST_LIMIT}`,
      [userId],
    ),
  );
}

export function createBuddy(db: Db, userId: string, draft: BuddyDraft): Promise<BuddyRequest> {
  return db.asUser(userId, async (tx) => {
    const [{ id }] = await tx.query<{ id: string }>(
      `INSERT INTO partner_sessions (host_id, starts_at, place, focus, note)
       VALUES ($1::uuid, $2, $3, $4, $5) RETURNING id::text`,
      [userId, draft.startsAt, draft.place, draft.focus, draft.note],
    );
    return buddyById(tx, userId, id);
  });
}

export function deleteBuddy(db: Db, userId: string, id: string): Promise<void> {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM partner_sessions WHERE id = $1::uuid AND host_id = $2::uuid RETURNING id", [
      id,
      userId,
    ]);
    if (rows.length === 0) throw notFound("Tréning");
  });
}

export function joinBuddy(db: Db, userId: string, id: string, join: boolean): Promise<BuddyRequest> {
  return db.asUser(userId, async (tx) => {
    const session = await buddyById(tx, userId, id);
    if (join) {
      if (session.mine) throw new HttpError(409, "own_session", "Toto je tvoj tréning.");
      if (session.startsAt.getTime() < Date.now() - 2 * 3600_000) throw ended("Tréning");
      await tx.query(
        "INSERT INTO partner_session_members (session_id, user_id) VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING",
        [id, userId],
      );
    } else {
      await tx.query("DELETE FROM partner_session_members WHERE session_id = $1::uuid AND user_id = $2::uuid", [id, userId]);
    }
    return buddyById(tx, userId, id);
  });
}

// ---------------------------------------------------------------- udalosti

export type CommunityEvent = {
  id: string;
  title: string;
  place: string;
  description: string | null;
  startsAt: Date;
  organizerName: string;
  attendees: number;
  joined: boolean;
  mine: boolean;
};

export type EventDraft = { title: string; place: string; description: string | null; startsAt: Date };

const EVENT_COLUMNS = `
  e.id::text, e.title, e.place, e.description, e.starts_at AS "startsAt",
  coalesce(pp.display_name, 'Používateľ') AS "organizerName",
  (SELECT count(*)::int FROM community_event_attendees a WHERE a.event_id = e.id) AS attendees,
  EXISTS (SELECT 1 FROM community_event_attendees a WHERE a.event_id = e.id AND a.user_id = $1::uuid) AS joined,
  e.created_by = $1::uuid AS mine`;

async function eventById(tx: Tx, userId: string, id: string): Promise<CommunityEvent> {
  const [row] = await tx.query<CommunityEvent>(
    `SELECT ${EVENT_COLUMNS} FROM community_events e LEFT JOIN public_profiles pp ON pp.id = e.created_by
     WHERE e.id = $2::uuid`,
    [userId, id],
  );
  if (!row) throw notFound("Udalosť");
  return row;
}

export function events(db: Db, userId: string): Promise<CommunityEvent[]> {
  return db.asUser(userId, (tx) =>
    tx.query<CommunityEvent>(
      `SELECT ${EVENT_COLUMNS} FROM community_events e LEFT JOIN public_profiles pp ON pp.id = e.created_by
       WHERE e.starts_at > now() - interval '6 hours'
       ORDER BY e.starts_at, e.id LIMIT ${LIST_LIMIT}`,
      [userId],
    ),
  );
}

export function createEvent(db: Db, userId: string, draft: EventDraft): Promise<CommunityEvent> {
  return db.asUser(userId, async (tx) => {
    const [{ id }] = await tx.query<{ id: string }>(
      `INSERT INTO community_events (created_by, title, place, description, starts_at)
       VALUES ($1::uuid, $2, $3, $4, $5) RETURNING id::text`,
      [userId, draft.title, draft.place, draft.description, draft.startsAt],
    );
    // Organizátor prichádza na vlastnú udalosť.
    await tx.query("INSERT INTO community_event_attendees (event_id, user_id) VALUES ($1::uuid, $2::uuid)", [id, userId]);
    return eventById(tx, userId, id);
  });
}

export function deleteEvent(db: Db, userId: string, id: string): Promise<void> {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM community_events WHERE id = $1::uuid AND created_by = $2::uuid RETURNING id", [
      id,
      userId,
    ]);
    if (rows.length === 0) throw notFound("Udalosť");
  });
}

export function joinEvent(db: Db, userId: string, id: string, join: boolean): Promise<CommunityEvent> {
  return db.asUser(userId, async (tx) => {
    const event = await eventById(tx, userId, id);
    if (join) {
      if (event.startsAt.getTime() < Date.now() - 6 * 3600_000) throw ended("Udalosť");
      await tx.query(
        "INSERT INTO community_event_attendees (event_id, user_id) VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING",
        [id, userId],
      );
    } else {
      await tx.query("DELETE FROM community_event_attendees WHERE event_id = $1::uuid AND user_id = $2::uuid", [id, userId]);
    }
    return eventById(tx, userId, id);
  });
}

// ------------------------------------------------------------------ výzvy

export type Challenge = {
  id: string;
  title: string;
  description: string | null;
  goalDays: number;
  startsOn: string;
  endsOn: string;
  members: number;
  joined: boolean;
  mine: boolean;
  /** Moje dni s tréningom vo výzve, null keď nie som členom. */
  myDays: number | null;
};

export type ChallengeDraft = {
  title: string;
  description: string | null;
  goalDays: number;
  startsOn: string;
  endsOn: string;
};

const CHALLENGE_COLUMNS = `
  c.id::text, c.title, c.description, c.goal_days AS "goalDays",
  to_char(c.starts_on, 'YYYY-MM-DD') AS "startsOn", to_char(c.ends_on, 'YYYY-MM-DD') AS "endsOn",
  (SELECT count(*)::int FROM community_challenge_members m WHERE m.challenge_id = c.id) AS members,
  EXISTS (SELECT 1 FROM community_challenge_members m WHERE m.challenge_id = c.id AND m.user_id = $1::uuid) AS joined,
  c.created_by = $1::uuid AS mine,
  challenge_progress(c.id, $1::uuid, $2) AS "myDays"`;

async function challengeById(tx: Tx, userId: string, id: string): Promise<Challenge> {
  const [row] = await tx.query<Challenge>(
    `SELECT ${CHALLENGE_COLUMNS} FROM community_challenges c WHERE c.id = $3::uuid`,
    [userId, ZONE, id],
  );
  if (!row) throw notFound("Výzva");
  return row;
}

/** Bežiace a nadchádzajúce výzvy, moje navrchu. */
export function challenges(db: Db, userId: string): Promise<Challenge[]> {
  return db.asUser(userId, (tx) =>
    tx.query<Challenge>(
      `SELECT ${CHALLENGE_COLUMNS} FROM community_challenges c
       WHERE c.ends_on >= (now() AT TIME ZONE $2)::date
       ORDER BY joined DESC, c.starts_on, c.id LIMIT ${LIST_LIMIT}`,
      [userId, ZONE],
    ),
  );
}

/** Kontrola dátumov výzvy (aj databáza má rovnaké pravidlá). */
export function checkChallengeDates(draft: ChallengeDraft, today: string): void {
  const days = (Date.parse(draft.endsOn) - Date.parse(draft.startsOn)) / 86_400_000 + 1;
  if (draft.endsOn < today) throw new HttpError(400, "invalid_endsOn", "Výzva musí skončiť dnes alebo neskôr.");
  if (days < 1 || days > 367) throw new HttpError(400, "invalid_dates", "Výzva trvá 1 deň až 1 rok.");
  if (draft.goalDays > days) throw new HttpError(400, "invalid_goalDays", "Cieľ je viac dní, ako výzva trvá.");
}

export function createChallenge(db: Db, userId: string, draft: ChallengeDraft): Promise<Challenge> {
  return db.asUser(userId, async (tx) => {
    const [{ today }] = await tx.query<{ today: string }>(
      "SELECT to_char((now() AT TIME ZONE $1)::date, 'YYYY-MM-DD') AS today",
      [ZONE],
    );
    checkChallengeDates(draft, today);
    const [{ id }] = await tx.query<{ id: string }>(
      `INSERT INTO community_challenges (created_by, title, description, goal_days, starts_on, ends_on)
       VALUES ($1::uuid, $2, $3, $4, $5::date, $6::date) RETURNING id::text`,
      [userId, draft.title, draft.description, draft.goalDays, draft.startsOn, draft.endsOn],
    );
    await tx.query("INSERT INTO community_challenge_members (challenge_id, user_id) VALUES ($1::uuid, $2::uuid)", [id, userId]);
    return challengeById(tx, userId, id);
  });
}

export function deleteChallenge(db: Db, userId: string, id: string): Promise<void> {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query(
      "DELETE FROM community_challenges WHERE id = $1::uuid AND created_by = $2::uuid RETURNING id",
      [id, userId],
    );
    if (rows.length === 0) throw notFound("Výzva");
  });
}

export function joinChallenge(db: Db, userId: string, id: string, join: boolean): Promise<Challenge> {
  return db.asUser(userId, async (tx) => {
    await challengeById(tx, userId, id);
    if (join) {
      await tx.query(
        "INSERT INTO community_challenge_members (challenge_id, user_id) VALUES ($1::uuid, $2::uuid) ON CONFLICT DO NOTHING",
        [id, userId],
      );
    } else {
      await tx.query("DELETE FROM community_challenge_members WHERE challenge_id = $1::uuid AND user_id = $2::uuid", [
        id,
        userId,
      ]);
    }
    return challengeById(tx, userId, id);
  });
}

// --------------------------------------------------------------- rebríček

export type LeaderboardEntry = { name: string; city: string | null; days: number; me: boolean };
export type Leaderboard = { optedIn: boolean; entries: LeaderboardEntry[] };

async function leaderboardIn(tx: Tx, userId: string): Promise<Leaderboard> {
  const [me] = await tx.query<{ optedIn: boolean }>(
    'SELECT leaderboard_opt_in AS "optedIn" FROM users WHERE id = $1::uuid',
    [userId],
  );
  const entries = await tx.query<LeaderboardEntry>(
    `SELECT display_name AS name, city, days, user_id = $1::uuid AS me
     FROM weekly_activity_leaderboard($2, $3) WHERE days > 0`,
    [userId, ZONE, LEADERBOARD_LIMIT],
  );
  return { optedIn: me?.optedIn ?? false, entries };
}

/** Najaktívnejší za posledných 7 dní (len tí, čo si rebríček zapli). */
export function leaderboard(db: Db, userId: string): Promise<Leaderboard> {
  return db.asUser(userId, (tx) => leaderboardIn(tx, userId));
}

export function setLeaderboardOptIn(db: Db, userId: string, enabled: boolean): Promise<Leaderboard> {
  return db.asUser(userId, async (tx) => {
    await tx.query("UPDATE users SET leaderboard_opt_in = $2 WHERE id = $1::uuid", [userId, enabled]);
    return leaderboardIn(tx, userId);
  });
}

/** Moje miesto v týždennom rebríčku pre domovskú obrazovku. */
export type MyRanking = { position: number; total: number; days: number };

export async function myRanking(tx: Tx, userId: string): Promise<MyRanking | null> {
  const { optedIn, entries } = await leaderboardIn(tx, userId);
  const index = entries.findIndex((e) => e.me);
  if (!optedIn || index < 0) return null;
  return { position: index + 1, total: entries.length, days: entries[index].days };
}

/** Najbližší spoločný tréning od niekoho iného, ku ktorému sa ešte dá pridať. */
export async function nextBuddyRequest(tx: Tx, userId: string): Promise<BuddyRequest | null> {
  const [row] = await tx.query<BuddyRequest>(
    `SELECT ${BUDDY_COLUMNS} FROM partner_sessions s LEFT JOIN public_profiles pp ON pp.id = s.host_id
     WHERE s.starts_at > now() AND s.host_id <> $1::uuid
       AND NOT EXISTS (SELECT 1 FROM partner_session_members m WHERE m.session_id = s.id AND m.user_id = $1::uuid)
     ORDER BY s.starts_at, s.id LIMIT 1`,
    [userId],
  );
  return row ?? null;
}
