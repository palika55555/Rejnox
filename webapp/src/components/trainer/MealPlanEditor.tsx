"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { saveMealPlan } from "@/app/trener/actions";
import type { MealPlanInput } from "@/server/mealPlans";
import { AiAssistant } from "./AiAssistant";

const DAYS = ["Po", "Ut", "St", "Št", "Pi", "So", "Ne"];
const MEALS = ["Raňajky", "Desiata", "Obed", "Olovrant", "Večera", "Pred tréningom", "Po tréningu"];

type Row = {
  key: string;
  id: string | null;
  day: number;
  meal: string;
  name: string;
  amount: string;
  kcal: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
};

export type EditorPlan = {
  id: string | null;
  title: string;
  note: string;
  startsOn: string;
  targets: { kcal: number | null; proteinG: number | null; carbsG: number | null; fatG: number | null };
  items: Omit<Row, "key">[];
};

type Props = { clientId: string; clientName: string; canSend: boolean; plan: EditorPlan };

let counter = 0;
const newKey = () => `r${++counter}`;
const num = (v: string) => (v === "" ? 0 : Number(v));

/** Editor jedálnička na týždeň: dni, jedlá, makrá a súčty oproti cieľu. */
export function MealPlanEditor({ clientId, clientName, canSend, plan }: Props) {
  const router = useRouter();
  const [title, setTitle] = useState(plan.title);
  const [note, setNote] = useState(plan.note);
  const [startsOn, setStartsOn] = useState(plan.startsOn);
  const [targets, setTargets] = useState(plan.targets);
  const [rows, setRows] = useState<Row[]>(() => plan.items.map((i) => ({ ...i, key: newKey() })));
  const [day, setDay] = useState(0);
  const [message, setMessage] = useState<{ text: string; isError: boolean } | null>(null);
  const [isPending, startTransition] = useTransition();

  const dayRows = rows.filter((r) => r.day === day);
  const totals = (d: number) =>
    rows.filter((r) => r.day === d).reduce(
      (s, r) => ({ kcal: s.kcal + r.kcal, proteinG: s.proteinG + r.proteinG, carbsG: s.carbsG + r.carbsG, fatG: s.fatG + r.fatG }),
      { kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 },
    );
  const today = totals(day);

  const update = (key: string, patch: Partial<Row>) =>
    setRows((all) => all.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  const addRow = () =>
    setRows((all) => [
      ...all,
      { key: newKey(), id: null, day, meal: MEALS[Math.min(dayRows.length, MEALS.length - 1)], name: "", amount: "", kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 },
    ]);
  const copyDayToAll = () => {
    if (!window.confirm(`Prepísať ostatné dni jedlami z dňa ${DAYS[day]}?`)) return;
    setRows((all) => [
      ...all.filter((r) => r.day === day),
      ...[0, 1, 2, 3, 4, 5, 6].filter((d) => d !== day).flatMap((d) => dayRows.map((r) => ({ ...r, key: newKey(), id: null, day: d }))),
    ]);
  };

  const save = (sendNow: boolean) =>
    startTransition(async () => {
      const payload = {
        title,
        note: note || null,
        startsOn: startsOn || null,
        targets,
        items: rows.map((r) => ({
          id: r.id, day: r.day, meal: r.meal, name: r.name, amount: r.amount || null,
          kcal: r.kcal, proteinG: r.proteinG, carbsG: r.carbsG, fatG: r.fatG,
        })),
      };
      const result = await saveMealPlan(clientId, plan.id, payload, sendNow);
      if (!result.ok) {
        setMessage({ text: result.message, isError: true });
        return;
      }
      setMessage({ text: result.sent ? `Odoslané – ${clientName} ho už vidí v appke.` : "Uložené.", isError: false });
      if (!plan.id) router.replace(`/trener/klienti/${clientId}/jedalnicek/${result.planId}`);
    });

  const applyDraft = (draft: MealPlanInput) => {
    setTitle(draft.title);
    setNote(draft.note ?? "");
    setTargets(draft.targets);
    setRows(draft.items.map((i) => ({ ...i, id: null, amount: i.amount ?? "", key: newKey() })));
    setDay(0);
    setMessage({ text: "Návrh je hotový. Skontroluj ho a ulož.", isError: false });
  };

  const input = "rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent";
  const targetField = (key: keyof EditorPlan["targets"], label: string) => (
    <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
      {label}
      <input
        type="number"
        min={0}
        className={input}
        value={targets[key] ?? ""}
        onChange={(e) => setTargets({ ...targets, [key]: e.target.value === "" ? null : Number(e.target.value) })}
      />
    </label>
  );

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_18rem]">
      <div className="min-w-0 space-y-6">
        <AiAssistant clientId={clientId} targets={targets} hasItems={rows.length > 0} onDraft={applyDraft} />
        <section className="grid gap-3 rounded-3xl border border-line bg-surface p-5 sm:grid-cols-2">
          <label className="flex flex-col gap-1 text-xs font-semibold text-muted sm:col-span-2">
            Názov
            <input className={`${input} text-lg font-bold`} maxLength={120} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Redukcia – týždeň 1" />
          </label>
          <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
            Začiatok
            <input type="date" className={input} value={startsOn} onChange={(e) => setStartsOn(e.target.value)} />
          </label>
          <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
            Poznámka pre klienta
            <input className={input} maxLength={1000} value={note} onChange={(e) => setNote(e.target.value)} placeholder="pi 3 l vody denne…" />
          </label>
          <div className="grid grid-cols-4 gap-2 sm:col-span-2">
            {targetField("kcal", "Cieľ kcal")}
            {targetField("proteinG", "Bielkoviny g")}
            {targetField("carbsG", "Sacharidy g")}
            {targetField("fatG", "Tuky g")}
          </div>
        </section>

        <section className="rounded-3xl border border-line bg-surface p-5">
          <div className="flex flex-wrap gap-1.5" role="tablist" aria-label="Deň v týždni">
            {DAYS.map((name, d) => (
              <button
                key={name}
                type="button"
                role="tab"
                aria-selected={d === day}
                onClick={() => setDay(d)}
                className={`rounded-2xl px-3.5 py-2 text-sm font-bold transition-colors ${d === day ? "bg-accent text-white" : "bg-night text-muted hover:text-ink"}`}
              >
                {name}
                <span className="ml-1.5 text-xs font-normal opacity-80">{totals(d).kcal}</span>
              </button>
            ))}
          </div>

          <ul className="mt-5 space-y-2">
            {dayRows.map((r) => (
              <li key={r.key} className="grid grid-cols-2 gap-2 rounded-2xl bg-night/60 p-3 sm:grid-cols-[8rem_1fr_6rem_repeat(4,4.5rem)_2rem]">
                <select aria-label="Jedlo dňa" className={input} value={r.meal} onChange={(e) => update(r.key, { meal: e.target.value })}>
                  {[...new Set([...MEALS, r.meal])].map((m) => <option key={m}>{m}</option>)}
                </select>
                <input aria-label="Jedlo" className={input} maxLength={120} value={r.name} placeholder="Ovsená kaša s banánom" onChange={(e) => update(r.key, { name: e.target.value })} />
                <input aria-label="Množstvo" className={input} maxLength={60} value={r.amount} placeholder="80 g" onChange={(e) => update(r.key, { amount: e.target.value })} />
                {(["kcal", "proteinG", "carbsG", "fatG"] as const).map((f) => (
                  <input
                    key={f}
                    aria-label={{ kcal: "kcal", proteinG: "Bielkoviny", carbsG: "Sacharidy", fatG: "Tuky" }[f]}
                    type="number"
                    min={0}
                    step={f === "kcal" ? 1 : 0.1}
                    className={input}
                    value={r[f] || ""}
                    placeholder={{ kcal: "kcal", proteinG: "B", carbsG: "S", fatG: "T" }[f]}
                    onChange={(e) => update(r.key, { [f]: f === "kcal" ? Math.round(num(e.target.value)) : num(e.target.value) })}
                  />
                ))}
                <button type="button" aria-label="Odstrániť jedlo" onClick={() => setRows((all) => all.filter((x) => x.key !== r.key))} className="text-muted hover:text-plate-red">
                  ✕
                </button>
              </li>
            ))}
          </ul>
          <div className="mt-4 flex flex-wrap gap-2">
            <button type="button" onClick={addRow} className="rounded-full border border-dashed border-accent px-4 py-2 text-sm font-bold text-accent hover:bg-accent/10">
              + Pridať jedlo
            </button>
            {dayRows.length > 0 && (
              <button type="button" onClick={copyDayToAll} className="rounded-full px-4 py-2 text-sm text-muted hover:text-ink">
                Skopírovať {DAYS[day]} na celý týždeň
              </button>
            )}
          </div>
        </section>
      </div>

      <aside className="space-y-4 lg:sticky lg:top-24 lg:self-start">
        <section className="rounded-3xl border border-line bg-surface p-5">
          <h2 className="text-xs font-semibold tracking-[0.18em] text-muted uppercase">{DAYS[day]} – súčet</h2>
          <p className="mt-2 font-display text-5xl font-black">{today.kcal}<span className="ml-1 text-base text-muted">kcal</span></p>
          {targets.kcal ? <Bar value={today.kcal} target={targets.kcal} /> : null}
          <dl className="mt-4 grid grid-cols-3 gap-2 text-center text-sm">
            {([["B", today.proteinG, targets.proteinG], ["S", today.carbsG, targets.carbsG], ["T", today.fatG, targets.fatG]] as const).map(([l, v, t]) => (
              <div key={l} className="rounded-2xl bg-night/60 py-2">
                <dt className="text-[11px] text-muted">{l}</dt>
                <dd className="font-bold">{Math.round(v)}{t ? <span className="text-muted">/{t}</span> : null} g</dd>
              </div>
            ))}
          </dl>
        </section>
        <div className="flex flex-col gap-2">
          <button type="button" disabled={isPending} onClick={() => save(false)} className="rounded-full border border-line px-5 py-3 text-sm font-bold hover:border-accent disabled:opacity-60">
            {isPending ? "Ukladám…" : "Uložiť koncept"}
          </button>
          {canSend && (
            <button type="button" disabled={isPending || rows.length === 0} onClick={() => save(true)} className="btn-action rounded-full px-5 py-3 text-sm font-bold text-white shadow-lg shadow-accent/20 disabled:opacity-60">
              Uložiť a odoslať klientovi
            </button>
          )}
          {message && (
            <p role={message.isError ? "alert" : "status"} className={`text-sm ${message.isError ? "text-plate-red" : "text-good"}`}>
              {message.text}
            </p>
          )}
        </div>
      </aside>
    </div>
  );
}

function Bar({ value, target }: { value: number; target: number }) {
  const pct = Math.round((value / target) * 100);
  const tone = pct > 110 ? "bg-plate-red" : pct >= 90 ? "bg-good" : "bg-flame";
  return (
    <div className="mt-3">
      <div className="h-2 overflow-hidden rounded-full bg-night">
        <div className={`h-full rounded-full ${tone}`} style={{ width: `${Math.min(pct, 100)}%` }} />
      </div>
      <p className="mt-1 text-xs text-muted">{pct} % z cieľa {target} kcal</p>
    </div>
  );
}
