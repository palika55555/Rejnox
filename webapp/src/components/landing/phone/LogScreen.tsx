"use client";

import { useEffect, useState } from "react";
import { Barbell } from "../Barbell";
import { demoExercises, formatKg, groupLabel, plateColor, type DemoExercise } from "../exercises";

type DemoSet = {
  id: number;
  exercise: DemoExercise;
  reps: number;
  weightKg: number;
  synced: boolean;
};

const GOAL = 6;

const initialSets: DemoSet[] = [
  { id: 1, exercise: demoExercises[0], reps: 8, weightKg: 80, synced: true },
  { id: 2, exercise: demoExercises[0], reps: 8, weightKg: 80, synced: true },
];

type Props = {
  online: boolean;
  /** Zavolá sa po zapísaní série (telefón ukáže živú aktivitu). */
  onLogged?: (text: string) => void;
};

/** Obrazovka zápisu série z mobilnej appky, vrátane práce bez internetu. */
export function LogScreen({ online, onLogged }: Props) {
  const [sets, setSets] = useState<DemoSet[]>(initialSets);
  const [exercise, setExercise] = useState<DemoExercise>(demoExercises[0]);
  const [reps, setReps] = useState(exercise.reps);
  const [weight, setWeight] = useState(exercise.weightKg);

  const pending = sets.filter((s) => !s.synced).length;
  const done = sets.length >= GOAL;

  // Kým je signál, čakajúce série sa odosielajú jedna po druhej.
  useEffect(() => {
    if (!online || pending === 0) return;
    const timer = setTimeout(() => {
      setSets((all) => {
        const index = all.findIndex((s) => !s.synced);
        return all.map((s, i) => (i === index ? { ...s, synced: true } : s));
      });
    }, 900);
    return () => clearTimeout(timer);
  }, [online, pending, sets]);

  function pickExercise(next: DemoExercise) {
    setExercise(next);
    setReps(next.reps);
    setWeight(next.weightKg);
  }

  function logSet() {
    if (done) return;
    setSets((all) => [...all, { id: Date.now(), exercise, reps, weightKg: weight, synced: false }]);
    onLogged?.(online ? `${exercise.name} · ${reps} × ${formatKg(weight)}` : "Uložené v telefóne");
  }

  const status = !online
    ? pending > 0
      ? `Bez internetu. ${pending} ${pending === 1 ? "séria čaká" : pending < 5 ? "série čakajú" : "sérií čaká"} v telefóne.`
      : "Bez internetu. Série sa uložia v telefóne."
    : pending > 0
      ? "Odosielam na server…"
      : "Všetko uložené";

  return (
    <div className="px-5 pb-6">
      <p className="mt-4 text-xs text-muted">Plán od trénera na dnes</p>
      <h3 className="font-display text-2xl font-extrabold tracking-tight">Dnešný tréning</h3>

      <div className="mt-4">
        <div className="flex items-baseline justify-between text-xs">
          <span className="font-semibold">
            {sets.length} z {GOAL} sérií
          </span>
          <span className="text-muted">Každá séria pridá kotúč</span>
        </div>
        <Barbell
          className="mt-2 h-14 w-full"
          total={GOAL}
          plates={sets.map((s) => ({ key: String(s.id), color: plateColor[s.exercise.group] }))}
        />
      </div>

      <div className="mt-4 flex flex-wrap gap-1.5" role="radiogroup" aria-label="Cvik">
        {demoExercises.map((e) => {
          const active = e.id === exercise.id;
          return (
            <button
              key={e.id}
              type="button"
              role="radio"
              aria-checked={active}
              onClick={() => pickExercise(e)}
              className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold transition-colors ${
                active ? "border-accent bg-surface-hi text-ink" : "border-line text-muted hover:text-ink"
              }`}
            >
              <span className="size-2 rounded-full" style={{ background: plateColor[e.group] }} />
              {e.name}
            </button>
          );
        })}
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        <Stepper
          label="Opakovania"
          value={String(reps)}
          onMinus={() => setReps((r) => Math.max(1, r - 1))}
          onPlus={() => setReps((r) => Math.min(50, r + 1))}
        />
        <Stepper
          label="Váha"
          value={formatKg(weight)}
          onMinus={() => setWeight((w) => Math.max(0, w - 2.5))}
          onPlus={() => setWeight((w) => Math.min(400, w + 2.5))}
        />
      </div>

      <button
        type="button"
        onClick={done ? () => setSets([]) : logSet}
        className="btn-action btn-shine mt-3 w-full rounded-xl py-3 text-sm font-bold text-white transition-transform active:scale-[0.98]"
      >
        {done ? "Začať odznova" : "Zapísať sériu"}
      </button>

      <ul className="mt-4 space-y-1.5" aria-live="polite">
        {sets
          .slice(-3)
          .reverse()
          .map((s) => (
            <li
              key={s.id}
              className="row-in flex items-center justify-between rounded-lg bg-surface px-3 py-2 text-xs"
            >
              <span className="flex items-center gap-2">
                <span className="size-2 rounded-full" style={{ background: plateColor[s.exercise.group] }} />
                <span className="font-semibold">{s.exercise.name}</span>
                <span className="text-muted">
                  {s.reps} × {formatKg(s.weightKg)}
                </span>
              </span>
              <span className={s.synced ? "text-plate-green" : "text-flame"}>{s.synced ? "Uložené" : "Čaká"}</span>
            </li>
          ))}
      </ul>

      <p className="mt-3 text-[11px] text-muted" role="status">
        {status}
      </p>
      <p className="sr-only">Svalové partie: {Object.values(groupLabel).join(", ")}.</p>
    </div>
  );
}

function Stepper({
  label,
  value,
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  onMinus: () => void;
  onPlus: () => void;
}) {
  return (
    <div className="rounded-xl border border-line bg-surface px-2 py-2">
      <p className="px-1 text-[11px] text-muted">{label}</p>
      <div className="mt-1 flex items-center justify-between">
        <button
          type="button"
          onClick={onMinus}
          aria-label={`${label}: menej`}
          className="grid size-7 place-items-center rounded-lg bg-surface-hi text-base leading-none"
        >
          −
        </button>
        <span className="font-display text-sm font-extrabold tabular-nums">{value}</span>
        <button
          type="button"
          onClick={onPlus}
          aria-label={`${label}: viac`}
          className="grid size-7 place-items-center rounded-lg bg-surface-hi text-base leading-none"
        >
          +
        </button>
      </div>
    </div>
  );
}
