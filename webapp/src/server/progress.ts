import type { Db } from "./db";
import { MY_SETS, ZONE, shift } from "./home";

/** Koľko týždňov ukazuje graf objemu. */
const WEEKS = 12;

/** Koľko dní dozadu sa ráta „posledný mesiac“ (a porovnáva s mesiacom pred ním). */
const MONTH_DAYS = 30;

/** Bodov v grafe jedného cviku. */
const TREND_POINTS = 12;

/** Najviac cvikov v zozname (najnovšie odcvičené hore). */
const MAX_EXERCISES = 40;

/**
 * Odhad maxima na 1 opakovanie (Epley). Pri viac ako 12 opakovaniach je odhad
 * nespoľahlivý, preto sa také série do neho nerátajú.
 */
const E1RM_SQL = "CASE WHEN m.reps = 1 THEN m.kg WHEN m.reps <= 12 THEN m.kg * (1 + m.reps / 30.0) END";

/** Jeden deň jedného cviku: súhrn jeho sérií. */
export type DayRow = {
  day: string;
  exerciseId: string;
  name: string;
  muscleGroup: string | null;
  sets: number;
  volumeKg: number;
  bestKg: number;
  e1rmKg: number | null;
};

export type WeekStat = { start: string; days: number; sets: number; volumeKg: number };

export type ExerciseProgress = {
  exerciseId: string;
  name: string;
  muscleGroup: string | null;
  bestKg: number;
  bestE1rmKg: number | null;
  /** Najťažšia séria v prvý deň, keď bol cvik odcvičený (východisko zlepšenia). */
  firstKg: number;
  lastDay: string;
  days: number;
  trend: { day: string; kg: number }[];
};

export type Progress = {
  totals: { trainingDays: number; sets: number; volumeKg: number };
  month: { days: number; sets: number; volumeKg: number; prevVolumeKg: number };
  weeks: WeekStat[];
  exercises: ExerciseProgress[];
  muscles: { muscleGroup: string; sets: number }[];
};

/** Pondelok týždňa, do ktorého patrí deň „YYYY-MM-DD“. */
export function mondayOf(day: string): string {
  const weekday = (new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7;
  return shift(day, -weekday);
}

const round1 = (n: number) => Math.round(n * 10) / 10;

/** Z denných súhrnov (zoradených od najstaršieho) spočíta celý prehľad progresu. */
export function summarize(rows: DayRow[], today: string): Progress {
  const monthStart = shift(today, -(MONTH_DAYS - 1));
  const prevStart = shift(monthStart, -MONTH_DAYS);

  // Týždne: posledných 12 vrátane tohto, aj prázdne.
  const thisMonday = mondayOf(today);
  const weeks = new Map<string, { days: Set<string>; sets: number; volumeKg: number }>();
  for (let i = WEEKS - 1; i >= 0; i--) {
    weeks.set(shift(thisMonday, -7 * i), { days: new Set(), sets: 0, volumeKg: 0 });
  }

  const allDays = new Set<string>();
  const monthDays = new Set<string>();
  let sets = 0;
  let volumeKg = 0;
  let monthSets = 0;
  let monthVolume = 0;
  let prevVolume = 0;
  const muscles = new Map<string, number>();
  const exercises = new Map<string, ExerciseProgress>();

  for (const r of rows) {
    allDays.add(r.day);
    sets += r.sets;
    volumeKg += r.volumeKg;

    if (r.day >= monthStart && r.day <= today) {
      monthDays.add(r.day);
      monthSets += r.sets;
      monthVolume += r.volumeKg;
      if (r.muscleGroup) muscles.set(r.muscleGroup, (muscles.get(r.muscleGroup) ?? 0) + r.sets);
    } else if (r.day >= prevStart && r.day < monthStart) {
      prevVolume += r.volumeKg;
    }

    const week = weeks.get(mondayOf(r.day));
    if (week) {
      week.days.add(r.day);
      week.sets += r.sets;
      week.volumeKg += r.volumeKg;
    }

    const prev = exercises.get(r.exerciseId);
    const e1rm = r.e1rmKg === null ? null : round1(r.e1rmKg);
    exercises.set(r.exerciseId, {
      exerciseId: r.exerciseId,
      name: r.name,
      muscleGroup: r.muscleGroup,
      bestKg: Math.max(prev?.bestKg ?? 0, r.bestKg),
      bestE1rmKg: prev?.bestE1rmKg == null ? e1rm : e1rm === null ? prev.bestE1rmKg : Math.max(prev.bestE1rmKg, e1rm),
      firstKg: prev?.firstKg ?? r.bestKg,
      lastDay: r.day,
      days: (prev?.days ?? 0) + 1,
      trend: [...(prev?.trend ?? []), { day: r.day, kg: r.bestKg }].slice(-TREND_POINTS),
    });
  }

  return {
    totals: { trainingDays: allDays.size, sets, volumeKg: Math.round(volumeKg) },
    month: {
      days: monthDays.size,
      sets: monthSets,
      volumeKg: Math.round(monthVolume),
      prevVolumeKg: Math.round(prevVolume),
    },
    weeks: [...weeks].map(([start, w]) => ({
      start,
      days: w.days.size,
      sets: w.sets,
      volumeKg: Math.round(w.volumeKg),
    })),
    exercises: [...exercises.values()]
      .sort((a, b) => b.lastDay.localeCompare(a.lastDay) || a.name.localeCompare(b.name, "sk"))
      .slice(0, MAX_EXERCISES),
    muscles: [...muscles]
      .map(([muscleGroup, n]) => ({ muscleGroup, sets: n }))
      .sort((a, b) => b.sets - a.sets),
  };
}

/** Progres používateľa: jeho série aj tie, čo mu zapísal tréner. */
export function progress(db: Db, userId: string): Promise<Progress> {
  return db.asUser(userId, async (tx) => {
    const [{ today }] = await tx.query<{ today: string }>(
      "SELECT to_char((now() AT TIME ZONE $1)::date, 'YYYY-MM-DD') AS today",
      [ZONE],
    );
    const rows = await tx.query<DayRow>(
      `WITH mine AS (${MY_SETS})
       SELECT to_char(m.day, 'YYYY-MM-DD') AS day, m.exercise_id::text AS "exerciseId", e.name,
              e.muscle_group AS "muscleGroup", count(*)::int AS sets,
              sum(m.reps * m.kg)::float8 AS "volumeKg", max(m.kg)::float8 AS "bestKg",
              max(${E1RM_SQL})::float8 AS "e1rmKg"
       FROM mine m JOIN exercises e ON e.id = m.exercise_id
       GROUP BY m.day, m.exercise_id, e.name, e.muscle_group
       ORDER BY m.day, e.name`,
      [userId, ZONE],
    );
    return summarize(rows, today);
  });
}
