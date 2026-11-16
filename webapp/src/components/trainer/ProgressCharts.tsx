import type { Nutrition } from "@/server/clientProgress";
import type { Progress } from "@/server/progress";
import { adherenceTone, kg, relativeDay, shortDay } from "./format";

/** Progres klienta: dodržiavanie jedálnička, objem po týždňoch a cviky. */
export function ProgressCharts({ training, nutrition, today }: { training: Progress; nutrition: Nutrition; today: string }) {
  return (
    <div className="grid gap-4 lg:grid-cols-5">
      <NutritionCard nutrition={nutrition} today={today} />
      <TotalsCard training={training} />
      <WeeksCard training={training} />
      <ExercisesCard training={training} today={today} />
    </div>
  );
}

function Card({ title, children, className = "" }: { title: string; children: React.ReactNode; className?: string }) {
  return (
    <section className={`rounded-3xl border border-line bg-surface p-5 sm:p-6 ${className}`}>
      <h3 className="text-xs font-semibold tracking-[0.18em] text-muted uppercase">{title}</h3>
      {children}
    </section>
  );
}

function NutritionCard({ nutrition, today }: { nutrition: Nutrition; today: string }) {
  const max = Math.max(1, ...nutrition.days.map((d) => d.plannedMeals));
  return (
    <Card title="Jedálniček – posledných 14 dní" className="lg:col-span-3">
      <div className="mt-3 flex flex-wrap items-baseline gap-x-4">
        <p className={`font-display text-6xl font-black ${adherenceTone(nutrition.adherencePct)}`}>
          {nutrition.adherencePct === null ? "–" : `${nutrition.adherencePct} %`}
        </p>
        <p className="text-sm text-muted">
          zjedených jedál z plánu · posledné odškrtnutie: {relativeDay(nutrition.lastCheckDay, today)}
        </p>
      </div>
      <div className="mt-6 flex h-32 items-end gap-1.5" role="img" aria-label="Zjedené a naplánované jedlá po dňoch">
        {nutrition.days.map((d) => {
          const planned = (d.plannedMeals / max) * 100;
          const eaten = d.plannedMeals ? (d.eatenMeals / max) * 100 : 0;
          return (
            <div key={d.day} className="group relative flex h-full flex-1 flex-col justify-end" title={`${shortDay(d.day)}: ${d.eatenMeals}/${d.plannedMeals} jedál, ${d.eatenKcal}/${d.plannedKcal} kcal`}>
              <div className="relative w-full rounded-lg bg-surface-hi" style={{ height: `${Math.max(planned, 4)}%` }}>
                <div className="absolute inset-x-0 bottom-0 rounded-lg bg-gradient-to-t from-accent to-flame" style={{ height: `${planned ? (eaten / planned) * 100 : 0}%` }} />
              </div>
            </div>
          );
        })}
      </div>
      <div className="mt-2 flex justify-between text-[11px] text-muted">
        <span>{shortDay(nutrition.days[0].day)}</span>
        <span>dnes</span>
      </div>
      <p className="mt-3 flex gap-4 text-xs text-muted">
        <span className="flex items-center gap-1.5"><i className="size-2.5 rounded-sm bg-accent" /> zjedené</span>
        <span className="flex items-center gap-1.5"><i className="size-2.5 rounded-sm bg-surface-hi" /> naplánované</span>
      </p>
    </Card>
  );
}

function TotalsCard({ training }: { training: Progress }) {
  const { month } = training;
  const delta = month.prevVolumeKg ? Math.round(((month.volumeKg - month.prevVolumeKg) / month.prevVolumeKg) * 100) : null;
  return (
    <Card title="Tréning – 30 dní" className="lg:col-span-2">
      <dl className="mt-4 grid grid-cols-2 gap-3">
        <Metric label="Tréningové dni" value={month.days} />
        <Metric label="Série" value={month.sets} />
        <Metric label="Objem" value={kg(month.volumeKg)} />
        <Metric
          label="Oproti minulému"
          value={delta === null ? "–" : `${delta > 0 ? "+" : ""}${delta} %`}
          tone={delta === null ? "" : delta >= 0 ? "text-good" : "text-plate-red"}
        />
      </dl>
      <p className="mt-4 text-xs text-muted">
        Spolu {training.totals.trainingDays} dní, {training.totals.sets} sérií s tebou.
      </p>
    </Card>
  );
}

function Metric({ label, value, tone = "" }: { label: string; value: number | string; tone?: string }) {
  return (
    <div className="rounded-2xl bg-night/60 p-3">
      <dt className="text-[11px] text-muted">{label}</dt>
      <dd className={`font-display text-2xl font-black ${tone}`}>{value}</dd>
    </div>
  );
}

function WeeksCard({ training }: { training: Progress }) {
  const max = Math.max(1, ...training.weeks.map((w) => w.volumeKg));
  return (
    <Card title="Objem po týždňoch" className="lg:col-span-2">
      <div className="mt-5 flex h-40 items-end gap-1.5" role="img" aria-label="Objem v kilogramoch za posledných 12 týždňov">
        {training.weeks.map((w) => (
          <div
            key={w.start}
            title={`Týždeň od ${shortDay(w.start)}: ${kg(w.volumeKg)}, ${w.days} dní`}
            className="flex-1 rounded-t-lg bg-gradient-to-t from-brand-blue/70 to-brand-violet"
            style={{ height: `${Math.max((w.volumeKg / max) * 100, w.volumeKg ? 4 : 1.5)}%`, opacity: w.volumeKg ? 1 : 0.25 }}
          />
        ))}
      </div>
      <div className="mt-2 flex justify-between text-[11px] text-muted">
        <span>{shortDay(training.weeks[0].start)}</span>
        <span>tento týždeň</span>
      </div>
    </Card>
  );
}

function Sparkline({ points }: { points: { kg: number }[] }) {
  if (points.length < 2) return <span className="text-xs text-muted">málo dát</span>;
  const values = points.map((p) => p.kg);
  const min = Math.min(...values);
  const span = Math.max(1, Math.max(...values) - min);
  const d = values
    .map((v, i) => `${i === 0 ? "M" : "L"}${(i / (values.length - 1)) * 100},${28 - ((v - min) / span) * 24}`)
    .join(" ");
  return (
    <svg viewBox="0 0 100 30" className="h-7 w-24" aria-hidden preserveAspectRatio="none">
      <path d={d} fill="none" stroke="var(--color-accent)" strokeWidth="2.5" vectorEffect="non-scaling-stroke" strokeLinecap="round" />
    </svg>
  );
}

function ExercisesCard({ training, today }: { training: Progress; today: string }) {
  const rows = training.exercises.slice(0, 8);
  return (
    <Card title="Cviky a rekordy" className="lg:col-span-3">
      {rows.length === 0 ? (
        <p className="mt-4 text-sm text-muted">Zatiaľ žiadne série zapísané v rámci vašej spolupráce.</p>
      ) : (
        <table className="mt-3 w-full text-sm">
          <thead className="text-left text-[11px] text-muted">
            <tr>
              <th className="py-2 font-medium">Cvik</th>
              <th className="py-2 font-medium">Najviac</th>
              <th className="hidden py-2 font-medium sm:table-cell">Zlepšenie</th>
              <th className="py-2 font-medium">Trend</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((e) => (
              <tr key={e.exerciseId} className="border-t border-line/60">
                <td className="py-2.5">
                  <p className="font-semibold">{e.name}</p>
                  <p className="text-xs text-muted">{relativeDay(e.lastDay, today)}</p>
                </td>
                <td className="py-2.5 font-display text-lg font-black">{kg(e.bestKg)}</td>
                <td className="hidden py-2.5 text-good sm:table-cell">
                  {e.bestKg > e.firstKg ? `+${kg(e.bestKg - e.firstKg)}` : "–"}
                </td>
                <td className="py-2.5">
                  <Sparkline points={e.trend} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Card>
  );
}
