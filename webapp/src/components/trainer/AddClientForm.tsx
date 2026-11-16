"use client";

import { useActionState, useState } from "react";
import { addClient, type AddClientState } from "@/app/trener/actions";

/** Tlačidlo, ktoré rozbalí krátky formulár na nového klienta. */
export function AddClientForm() {
  const [isOpen, setOpen] = useState(false);
  const [state, action, isPending] = useActionState<AddClientState, FormData>(addClient, undefined);

  if (!isOpen) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="btn-action rounded-full px-5 py-2.5 text-sm font-bold text-white shadow-lg shadow-accent/20 transition-transform hover:-translate-y-0.5"
      >
        + Nový klient
      </button>
    );
  }

  return (
    <form
      action={action}
      className="flex w-full flex-col gap-3 rounded-2xl border border-line bg-surface p-4 sm:w-auto sm:flex-row sm:items-start"
    >
      <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
        Meno
        <input
          name="name"
          required
          maxLength={60}
          autoFocus
          placeholder="Jana Nováková"
          className="rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
        Poznámka
        <input
          name="note"
          maxLength={500}
          placeholder="cieľ, zranenia…"
          className="rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent"
        />
      </label>
      <div className="flex gap-2 sm:pt-5">
        <button
          type="submit"
          disabled={isPending}
          className="btn-action rounded-full px-4 py-2 text-sm font-bold text-white disabled:opacity-60"
        >
          {isPending ? "Pridávam…" : "Pridať"}
        </button>
        <button type="button" onClick={() => setOpen(false)} className="rounded-full px-3 py-2 text-sm text-muted">
          Zrušiť
        </button>
      </div>
      {state?.message && (
        <p role="alert" className="text-sm text-plate-red sm:basis-full">
          {state.message}
        </p>
      )}
    </form>
  );
}
