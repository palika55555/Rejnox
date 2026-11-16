"use client";

import { useState, useTransition } from "react";
import { draftMealPlanWithAi, type AiDraftInput } from "@/app/trener/actions";
import type { MealPlanInput } from "@/server/mealPlans";

type Props = {
  clientId: string;
  targets: AiDraftInput["targets"];
  hasItems: boolean;
  onDraft: (plan: MealPlanInput) => void;
};

const EXAMPLES = [
  "Redukcia tuku, bez laktózy, rýchle raňajky do 5 minút",
  "Naberanie svalov, 4 tréningy týždenne, lacné suroviny",
  "Vegetarián, jedáva aj vajcia a mliečne výrobky",
];

/** AI pomocník: z krátkeho zadania navrhne celý týždeň, tréner ho potom upraví. */
export function AiAssistant({ clientId, targets, hasItems, onDraft }: Props) {
  const [isOpen, setOpen] = useState(false);
  const [brief, setBrief] = useState("");
  const [mealsPerDay, setMealsPerDay] = useState(4);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const handleGenerate = () => {
    if (hasItems && !window.confirm("Návrh nahradí jedlá, ktoré už v jedálničku sú. Pokračovať?")) return;
    setError(null);
    startTransition(async () => {
      const result = await draftMealPlanWithAi(clientId, { brief, mealsPerDay, targets });
      if (!result.ok) {
        setError(result.message);
        return;
      }
      onDraft(result.plan);
      setOpen(false);
    });
  };

  if (!isOpen) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="group flex w-full items-center gap-4 rounded-3xl border border-brand-violet/40 bg-gradient-to-r from-brand-blue/15 via-surface to-brand-violet/15 p-5 text-left transition-transform hover:-translate-y-0.5"
      >
        <span aria-hidden className="grid size-12 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-brand-blue to-brand-violet text-2xl">
          ✦
        </span>
        <span>
          <span className="block font-bold">AI pomocník</span>
          <span className="block text-sm text-muted">Napíš cieľ a obmedzenia, navrhne celý týždeň s makrami. Ty ho skontroluješ.</span>
        </span>
      </button>
    );
  }

  return (
    <section className="rounded-3xl border border-brand-violet/50 bg-surface p-5" aria-busy={isPending}>
      <div className="flex items-center justify-between gap-3">
        <h2 className="font-bold">✦ AI pomocník</h2>
        <button type="button" onClick={() => setOpen(false)} className="text-sm text-muted hover:text-ink">
          Zavrieť
        </button>
      </div>
      <label className="mt-3 flex flex-col gap-1 text-xs font-semibold text-muted">
        Zadanie (cieľ, alergie, čo nejí, rozpočet…)
        <textarea
          value={brief}
          maxLength={1500}
          rows={3}
          onChange={(e) => setBrief(e.target.value)}
          placeholder={EXAMPLES[0]}
          className="rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent"
        />
      </label>
      <div className="mt-2 flex flex-wrap gap-1.5">
        {EXAMPLES.map((example) => (
          <button
            key={example}
            type="button"
            onClick={() => setBrief(example)}
            className="rounded-full bg-night px-3 py-1 text-xs text-muted hover:text-ink"
          >
            {example}
          </button>
        ))}
      </div>
      <div className="mt-4 flex flex-wrap items-end gap-3">
        <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
          Jedál denne
          <select
            value={mealsPerDay}
            onChange={(e) => setMealsPerDay(Number(e.target.value))}
            className="rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink"
          >
            {[3, 4, 5, 6].map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </label>
        <p className="flex-1 text-xs text-muted">
          {targets.kcal ? `Použije cieľ ${targets.kcal} kcal z formulára.` : "Ciele nezadané – pomocník ich odhadne."}
        </p>
        <button
          type="button"
          onClick={handleGenerate}
          disabled={isPending}
          className="rounded-full bg-gradient-to-r from-brand-blue to-brand-violet px-5 py-2.5 text-sm font-bold text-white disabled:opacity-60"
        >
          {isPending ? "Navrhujem týždeň… (do minúty)" : "Navrhnúť jedálniček"}
        </button>
      </div>
      {error && (
        <p role="alert" className="mt-3 text-sm text-plate-red">
          {error}
        </p>
      )}
      <p className="mt-3 text-[11px] text-muted">
        Návrh vytvára AI (Google Gemini, bezplatná verzia – Google môže zadanie použiť na zlepšovanie služieb, preto doň nepíš mená ani zdravotné údaje). Pred odoslaním skontroluj množstvá aj alergény.
      </p>
    </section>
  );
}
