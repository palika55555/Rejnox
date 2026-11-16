/** Formátovanie pre trénerskú zónu (slovensky). */

const dayFormat = new Intl.DateTimeFormat("sk-SK", { day: "numeric", month: "numeric", timeZone: "UTC" });

/** „YYYY-MM-DD“ → „16. 11.“ */
export function shortDay(day: string): string {
  return dayFormat.format(new Date(`${day}T00:00:00Z`));
}

/** Koľko dní uplynulo od „YYYY-MM-DD“ po dnes. */
export function daysSince(day: string, today: string): number {
  return Math.round((Date.parse(`${today}T00:00:00Z`) - Date.parse(`${day}T00:00:00Z`)) / 86_400_000);
}

/** „dnes“, „včera“, „pred 5 dňami“. */
export function relativeDay(day: string | null, today: string): string {
  if (!day) return "zatiaľ nikdy";
  const n = daysSince(day, today);
  if (n <= 0) return "dnes";
  if (n === 1) return "včera";
  return `pred ${n} dňami`;
}

export function dateTime(value: Date | string): string {
  return new Intl.DateTimeFormat("sk-SK", {
    day: "numeric",
    month: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Bratislava",
  }).format(new Date(value));
}

export const kg = (n: number) => `${Math.round(n).toLocaleString("sk-SK")} kg`;

/** Farba podľa percenta dodržiavania jedálnička. */
export function adherenceTone(pct: number | null): string {
  if (pct === null) return "text-muted";
  if (pct >= 80) return "text-good";
  if (pct >= 50) return "text-flame";
  return "text-plate-red";
}
