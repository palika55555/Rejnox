"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { copyMealPlan, deleteMealPlan, sendMealPlan } from "@/app/trener/actions";

type Props = {
  clientId: string;
  planId: string;
  isSent: boolean;
  canSend: boolean;
  /** Ostatní aktívni klienti, ktorým sa dá jedálniček skopírovať. */
  otherClients: { id: string; name: string }[];
};

/** Odoslať, skopírovať a zmazať jedálniček zo zoznamu. */
export function PlanActions({ clientId, planId, isSent, canSend, otherClients }: Props) {
  const router = useRouter();
  const [message, setMessage] = useState<{ text: string; isError: boolean } | null>(null);
  const [isPending, startTransition] = useTransition();

  const run = (work: () => Promise<{ ok: boolean; message?: string }>, done: string) =>
    startTransition(async () => {
      const result = await work();
      setMessage(result.ok ? { text: done, isError: false } : { text: result.message ?? "Nepodarilo sa.", isError: true });
    });

  const handleSend = () => run(() => sendMealPlan(clientId, planId), "Odoslané do appky klienta.");

  const handleDelete = () => {
    if (!window.confirm("Naozaj zmazať tento jedálniček? Klient ho prestane vidieť.")) return;
    run(() => deleteMealPlan(clientId, planId), "Zmazané.");
  };

  const handleCopy = (target: string) => {
    if (!target) return;
    startTransition(async () => {
      const result = await copyMealPlan(clientId, planId, target);
      if (!result.ok) {
        setMessage({ text: result.message, isError: true });
        return;
      }
      router.push(`/trener/klienti/${target}/jedalnicek/${result.planId}`);
    });
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Link
        href={`/trener/klienti/${clientId}/jedalnicek/${planId}`}
        transitionTypes={["nav-forward"]}
        className="rounded-full border border-line px-3.5 py-1.5 text-sm font-semibold transition-colors hover:border-accent"
      >
        Upraviť
      </Link>
      {canSend && (
        <button
          type="button"
          onClick={handleSend}
          disabled={isPending}
          className="btn-action rounded-full px-3.5 py-1.5 text-sm font-bold text-white disabled:opacity-60"
        >
          {isSent ? "Poslať znova" : "Odoslať klientovi"}
        </button>
      )}
      <label className="sr-only" htmlFor={`copy-${planId}`}>
        Skopírovať klientovi
      </label>
      <select
        id={`copy-${planId}`}
        value=""
        disabled={isPending}
        onChange={(e) => handleCopy(e.target.value)}
        className="rounded-full border border-line bg-night px-3 py-1.5 text-sm text-muted outline-none hover:border-accent"
      >
        <option value="">Kopírovať…</option>
        <option value={clientId}>ako nový koncept</option>
        {otherClients.map((c) => (
          <option key={c.id} value={c.id}>
            → {c.name}
          </option>
        ))}
      </select>
      <button
        type="button"
        onClick={handleDelete}
        disabled={isPending}
        className="rounded-full px-3 py-1.5 text-sm text-muted transition-colors hover:text-plate-red"
      >
        Zmazať
      </button>
      {message && (
        <p role={message.isError ? "alert" : "status"} className={`basis-full text-sm ${message.isError ? "text-plate-red" : "text-good"}`}>
          {message.text}
        </p>
      )}
    </div>
  );
}
