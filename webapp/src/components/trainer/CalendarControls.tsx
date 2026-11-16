"use client";

import { useState, useTransition } from "react";
import {
  addBookingAction,
  addSlotAction,
  cancelBookingAction,
  confirmBookingAction,
  deleteSlotAction,
  type CalendarResult,
} from "@/app/trener/kalendar/actions";

function useAction() {
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const run = (work: () => Promise<CalendarResult>, after?: () => void) =>
    startTransition(async () => {
      const result = await work();
      setError(result.ok ? null : result.message);
      if (result.ok) after?.();
    });
  return { error, isPending, run };
}

/** Potvrdiť / odmietnuť / zrušiť tréning, zrušiť termín. */
export function EventActions({ kind, id, isRequested }: { kind: "booking" | "slot"; id: string; isRequested?: boolean }) {
  const { error, isPending, run } = useAction();
  const button = "rounded-full px-2.5 py-1 text-xs font-semibold transition-colors disabled:opacity-50";

  const cancel = () => {
    const question =
      kind === "slot" ? "Zrušiť termín? Rezervácie v ňom sa zrušia." : isRequested ? "Odmietnuť žiadosť?" : "Zrušiť tréning?";
    if (!window.confirm(question)) return;
    run(() => (kind === "slot" ? deleteSlotAction(id) : cancelBookingAction(id)));
  };

  return (
    <div className="mt-2 flex flex-wrap items-center gap-1.5">
      {isRequested && (
        <button
          type="button"
          disabled={isPending}
          onClick={() => run(() => confirmBookingAction(id))}
          className={`${button} bg-good/20 text-good hover:bg-good/30`}
        >
          Potvrdiť
        </button>
      )}
      <button type="button" disabled={isPending} onClick={cancel} className={`${button} text-muted hover:text-plate-red`}>
        {isRequested ? "Odmietnuť" : "Zrušiť"}
      </button>
      {error && (
        <p role="alert" className="basis-full text-xs text-plate-red">
          {error}
        </p>
      )}
    </div>
  );
}

type Client = { id: string; name: string };

/** Formulár: voľný termín pre klientov alebo tréning s konkrétnym klientom. */
export function AddEventForm({ clients, defaultDay }: { clients: Client[]; defaultDay: string }) {
  const [kind, setKind] = useState<"slot" | "booking">("slot");
  const [saved, setSaved] = useState(false);
  const { error, isPending, run } = useAction();
  const input = "rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent";
  const label = "flex flex-col gap-1 text-xs font-semibold text-muted";

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setSaved(false);
    run(
      () => (kind === "slot" ? addSlotAction(data) : addBookingAction(data)),
      () => setSaved(true),
    );
  };

  return (
    <section className="rounded-3xl border border-line bg-surface p-5">
      <div className="flex gap-1 rounded-full bg-night p-1" role="tablist" aria-label="Čo pridať">
        {(
          [
            ["slot", "Voľný termín"],
            ["booking", "Tréning s klientom"],
          ] as const
        ).map(([value, text]) => (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={kind === value}
            onClick={() => setKind(value)}
            className={`flex-1 rounded-full px-3 py-1.5 text-sm font-semibold ${kind === value ? "bg-accent text-white" : "text-muted"}`}
          >
            {text}
          </button>
        ))}
      </div>
      <p className="mt-3 text-xs text-muted">
        {kind === "slot"
          ? "Klienti si termín rezervujú v appke."
          : "Tréning sa klientovi rovno zapíše ako potvrdený."}
      </p>
      <form onSubmit={handleSubmit} className="mt-3 grid grid-cols-2 gap-3">
        {kind === "booking" && (
          <label className={`${label} col-span-2`}>
            Klient
            <select name="clientId" required className={input}>
              {clients.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>
        )}
        <label className={`${label} col-span-2`}>
          Deň
          <input type="date" name="day" required defaultValue={defaultDay} className={input} />
        </label>
        <label className={label}>
          Od
          <input type="time" name="from" required defaultValue="17:00" className={input} />
        </label>
        <label className={label}>
          Do
          <input type="time" name="to" required defaultValue="18:00" className={input} />
        </label>
        <label className={kind === "slot" ? label : `${label} col-span-2`}>
          Názov
          <input name="title" maxLength={80} placeholder={kind === "slot" ? "Osobný tréning" : "Nohy + core"} className={input} />
        </label>
        {kind === "slot" && (
          <label className={label}>
            Miest
            <input type="number" name="capacity" min={1} max={50} defaultValue={1} className={input} />
          </label>
        )}
        <label className={`${label} col-span-2`}>
          Poznámka
          <input name="note" maxLength={500} className={input} />
        </label>
        <button
          type="submit"
          disabled={isPending || (kind === "booking" && clients.length === 0)}
          className="btn-action col-span-2 rounded-full px-5 py-2.5 text-sm font-bold text-white disabled:opacity-50"
        >
          {isPending ? "Ukladám…" : kind === "slot" ? "Vypísať termín" : "Zapísať tréning"}
        </button>
        {error && (
          <p role="alert" className="col-span-2 text-sm text-plate-red">
            {error}
          </p>
        )}
        {saved && !error && (
          <p role="status" className="col-span-2 text-sm text-good">
            Uložené.
          </p>
        )}
      </form>
    </section>
  );
}
