"use client";

import { useState, useTransition } from "react";
import { inviteClient } from "@/app/trener/actions";
import { dateTime } from "./format";

/** Vydá pozývací kód, ktorý klient zadá v appke Rejnox. */
export function InviteButton({ clientId }: { clientId: string }) {
  const [invite, setInvite] = useState<{ code: string; expiresAt: string } | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const handleClick = () =>
    startTransition(async () => {
      const result = await inviteClient(clientId);
      if (result.ok) {
        setInvite({ code: result.code, expiresAt: result.expiresAt });
        setMessage(null);
      } else {
        setMessage(result.message);
      }
    });

  if (invite) {
    return (
      <div className="rounded-2xl border border-accent/50 bg-accent/10 px-4 py-3">
        <p className="text-xs text-muted">Kód pre klienta (appka → Tréner → Zadať kód)</p>
        <p className="font-mono text-2xl font-bold tracking-[0.2em] select-all">{invite.code}</p>
        <p className="text-xs text-muted">Platí do {dateTime(invite.expiresAt)}</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-start gap-1">
      <button
        type="button"
        onClick={handleClick}
        disabled={isPending}
        className="rounded-full border border-accent px-4 py-2 text-sm font-bold text-accent transition-colors hover:bg-accent hover:text-white disabled:opacity-60"
      >
        {isPending ? "Vytváram kód…" : "Pozvať do appky"}
      </button>
      {message && (
        <p role="alert" className="text-sm text-plate-red">
          {message}
        </p>
      )}
    </div>
  );
}
