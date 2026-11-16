"use client";

import { useState, useTransition } from "react";
import { sendBulkMessage } from "@/app/trener/actions";

type Client = { id: string; name: string; note: string | null; isLinked: boolean };

const TEMPLATES = [
  "Ahoj {meno}, zajtrajší tréning presúvame o hodinu neskôr. Vidíme sa!",
  "Ahoj {meno}, nový jedálniček máš v appke. Daj vedieť, ako ti sedí.",
  "{meno}, nezabudni si tento týždeň zapisovať série, nech vidíme progres.",
];

const firstName = (name: string) => name.trim().split(/\s+/)[0] ?? name;

/** Výber klientov a jedna správa, ktorá príde každému zvlášť do chatu. */
export function BulkMessageForm({ clients }: { clients: Client[] }) {
  const linked = clients.filter((c) => c.isLinked);
  const [selected, setSelected] = useState<Set<string>>(() => new Set(linked.map((c) => c.id)));
  const [text, setText] = useState("");
  const [result, setResult] = useState<{ text: string; isError: boolean } | null>(null);
  const [isPending, startTransition] = useTransition();

  const toggle = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  const allSelected = linked.length > 0 && linked.every((c) => selected.has(c.id));
  const previewName = linked.find((c) => selected.has(c.id))?.name ?? "Jana";

  const handleSend = () =>
    startTransition(async () => {
      const response = await sendBulkMessage([...selected], text);
      if (!response.ok) {
        setResult({ text: response.message, isError: true });
        return;
      }
      const skipped = response.skipped.length ? ` Preskočení (bez appky): ${response.skipped.join(", ")}.` : "";
      setResult({ text: `Odoslané ${response.sent.length} klientom.${skipped}`, isError: false });
      setText("");
    });

  return (
    <div className="grid gap-6 lg:grid-cols-[22rem_1fr]">
      <section className="rounded-3xl border border-line bg-surface p-5">
        <div className="flex items-center justify-between">
          <h2 className="text-xs font-semibold tracking-[0.18em] text-muted uppercase">Príjemcovia · {selected.size}</h2>
          <button
            type="button"
            onClick={() => setSelected(allSelected ? new Set() : new Set(linked.map((c) => c.id)))}
            className="text-sm font-semibold text-accent"
          >
            {allSelected ? "Zrušiť výber" : "Vybrať všetkých"}
          </button>
        </div>
        <ul className="mt-3 max-h-[28rem] space-y-1 overflow-y-auto">
          {clients.map((c) => (
            <li key={c.id}>
              <label
                className={`flex items-center gap-3 rounded-2xl px-3 py-2.5 ${c.isLinked ? "cursor-pointer hover:bg-night/60" : "opacity-45"}`}
              >
                <input
                  type="checkbox"
                  className="size-4 accent-[var(--color-accent)]"
                  checked={selected.has(c.id)}
                  disabled={!c.isLinked}
                  onChange={() => toggle(c.id)}
                />
                <span className="min-w-0">
                  <span className="block truncate font-semibold">{c.name}</span>
                  <span className="block truncate text-xs text-muted">
                    {c.isLinked ? (c.note ?? "prepojený s appkou") : "bez appky – správu nedostane"}
                  </span>
                </span>
              </label>
            </li>
          ))}
        </ul>
      </section>

      <section className="space-y-4">
        <div className="rounded-3xl border border-line bg-surface p-5">
          <label className="flex flex-col gap-1 text-xs font-semibold text-muted">
            Správa · {"{meno}"} sa nahradí krstným menom
            <textarea
              value={text}
              rows={6}
              maxLength={2000}
              onChange={(e) => setText(e.target.value)}
              placeholder="Ahoj {meno}, …"
              className="rounded-xl border border-line bg-night px-3 py-2 text-sm text-ink outline-none focus:border-accent"
            />
          </label>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {TEMPLATES.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setText(t)}
                className="rounded-full bg-night px-3 py-1 text-xs text-muted hover:text-ink"
              >
                {t.slice(0, 42)}…
              </button>
            ))}
          </div>
        </div>

        {text.trim() && (
          <div className="rounded-3xl border border-dashed border-line p-5">
            <p className="text-xs text-muted">Náhľad pre {previewName}</p>
            <p className="mt-2 max-w-md rounded-2xl rounded-bl-md bg-accent/90 px-4 py-2.5 whitespace-pre-wrap text-white">
              {text.replaceAll("{meno}", firstName(previewName))}
            </p>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={handleSend}
            disabled={isPending || selected.size === 0 || !text.trim()}
            className="btn-action rounded-full px-6 py-3 text-sm font-bold text-white shadow-lg shadow-accent/20 disabled:opacity-50"
          >
            {isPending ? "Posielam…" : `Poslať ${selected.size} klientom`}
          </button>
          {result && (
            <p role={result.isError ? "alert" : "status"} className={`text-sm ${result.isError ? "text-plate-red" : "text-good"}`}>
              {result.text}
            </p>
          )}
        </div>
      </section>
    </div>
  );
}
