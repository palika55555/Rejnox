/** Slovenský čas pre kalendár trénera (formuláre píšu dátum a čas v Bratislave). */

export const ZONE = "Europe/Bratislava";

const DAY_MS = 24 * 60 * 60 * 1000;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const timePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

/** O koľko minút je Bratislava v danom okamihu napred pred UTC (60 alebo 120). */
function offsetMinutes(instant: Date): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ZONE,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(instant);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  const local = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"));
  return Math.round((local - Math.floor(instant.getTime() / 60000) * 60000) / 60000);
}

/** „2026-11-16“ + „18:30“ (bratislavský čas) → okamih. Zlé vstupy → null. */
export function localToDate(day: string, time: string): Date | null {
  if (!datePattern.test(day) || !timePattern.test(time)) return null;
  const [y, m, d] = day.split("-").map(Number);
  const [hh, mm] = time.split(":").map(Number);
  const asUtc = Date.UTC(y, m - 1, d, hh, mm);
  if (new Date(asUtc).toISOString().slice(0, 10) !== day) return null;
  // Posun sa zistí dvakrát, aby sedel aj v deň zmeny času.
  const first = asUtc - offsetMinutes(new Date(asUtc)) * 60000;
  return new Date(asUtc - offsetMinutes(new Date(first)) * 60000);
}

/** Deň „YYYY-MM-DD“ v Bratislave pre daný okamih. */
export function localDay(instant: Date): string {
  return new Intl.DateTimeFormat("sv-SE", { timeZone: ZONE }).format(instant);
}

/** Čas „HH:MM“ v Bratislave. */
export function localTime(instant: Date): string {
  return new Intl.DateTimeFormat("sk-SK", { timeZone: ZONE, hour: "2-digit", minute: "2-digit" }).format(instant);
}

export function shiftDay(day: string, days: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + days * DAY_MS).toISOString().slice(0, 10);
}

/** Pondelok týždňa, do ktorého patrí deň. */
export function mondayOf(day: string): string {
  return shiftDay(day, -((new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7));
}

/** Pondelok z ?tyzden=…, inak tento týždeň. */
export function weekStart(param: unknown, now = new Date()): string {
  return typeof param === "string" && datePattern.test(param) && !Number.isNaN(Date.parse(param))
    ? mondayOf(param)
    : mondayOf(localDay(now));
}
