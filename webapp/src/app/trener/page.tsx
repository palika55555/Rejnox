import Link from "next/link";
import { AddClientForm } from "@/components/trainer/AddClientForm";
import { adherenceTone, relativeDay } from "@/components/trainer/format";
import { trainerData } from "@/lib/trainer";
import { trainerOverview, type ClientOverview } from "@/server/trainerOverview";

export default async function TrainerHomePage() {
  const { today, clients } = await trainerData((db, me) => trainerOverview(db, me.id));
  const active = clients.filter((c) => c.status !== "ended");
  const linked = active.filter((c) => c.status === "linked");
  const withPlan = active.filter((c) => c.latestPlan?.sentAt);
  const rated = active.filter((c) => c.adherencePct !== null);
  const avgAdherence = rated.length
    ? Math.round(rated.reduce((s, c) => s + (c.adherencePct ?? 0), 0) / rated.length)
    : null;
  const needsPlan = linked.filter((c) => !c.latestPlan?.sentAt);

  return (
    <>
      <section className="flex flex-wrap items-end justify-between gap-6">
        <div>
          <p className="text-sm font-semibold tracking-[0.2em] text-accent uppercase">Trénerská zóna</p>
          <h1 className="mt-2 font-display text-[clamp(2.2rem,5vw,3.6rem)] leading-none font-black tracking-[-0.02em]">
            Tvoji klienti
          </h1>
        </div>
        <AddClientForm />
      </section>

      <section className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4" aria-label="Súhrn">
        <Stat label="Aktívni klienti" value={active.length} hint={`${linked.length} s appkou`} big />
        <Stat label="S jedálničkom" value={withPlan.length} hint={`z ${linked.length} prepojených`} />
        <Stat
          label="Dodržiavanie jedál"
          value={avgAdherence === null ? "–" : `${avgAdherence} %`}
          hint="priemer za 14 dní"
          tone={adherenceTone(avgAdherence)}
        />
        <Stat label="Čaká na jedálniček" value={needsPlan.length} hint="prepojení bez odoslaného" accent />
      </section>

      {clients.length === 0 ? (
        <EmptyState />
      ) : (
        <ul className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {clients.map((c) => (
            <li key={c.id}>
              <ClientCard client={c} today={today} />
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

type StatProps = { label: string; value: number | string; hint: string; big?: boolean; accent?: boolean; tone?: string };

function Stat({ label, value, hint, big, accent, tone }: StatProps) {
  return (
    <div
      className={`relative overflow-hidden rounded-3xl border p-5 ${
        big ? "border-accent/40 bg-gradient-to-br from-accent/20 via-surface to-surface" : "border-line bg-surface"
      }`}
    >
      <p className="text-xs font-semibold tracking-wide text-muted uppercase">{label}</p>
      <p className={`mt-2 font-display text-5xl font-black ${tone ?? (accent ? "text-flame" : "")}`}>{value}</p>
      <p className="mt-1 text-sm text-muted">{hint}</p>
    </div>
  );
}

const statusLabel: Record<string, string> = {
  record_only: "Bez appky",
  invited: "Pozvaný",
  linked: "Prepojený",
  ended: "Ukončené",
};

function ClientCard({ client: c, today }: { client: ClientOverview; today: string }) {
  const planState = !c.latestPlan
    ? { text: "Bez jedálnička", tone: "text-muted" }
    : c.latestPlan.sentAt
      ? { text: `Odoslaný: ${c.latestPlan.title}`, tone: "text-good" }
      : { text: `Koncept: ${c.latestPlan.title}`, tone: "text-flame" };

  return (
    <Link
      href={`/trener/klienti/${c.id}`}
      transitionTypes={["nav-forward"]}
      className={`group flex h-full flex-col rounded-3xl border border-line bg-surface p-5 transition-all hover:-translate-y-0.5 hover:border-accent/60 hover:shadow-xl hover:shadow-black/30 ${
        c.status === "ended" ? "opacity-55" : ""
      }`}
    >
      <div className="flex items-start gap-3">
        <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-surface-hi font-display text-lg font-black text-accent">
          {c.name.slice(0, 1).toUpperCase()}
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-lg font-bold group-hover:text-accent">{c.name}</p>
          <p className="truncate text-sm text-muted">{c.note ?? "bez poznámky"}</p>
        </div>
        <span className="rounded-full border border-line px-2.5 py-0.5 text-xs font-semibold text-muted">
          {statusLabel[c.status] ?? c.status}
        </span>
      </div>

      <dl className="mt-5 grid grid-cols-3 gap-2 text-center">
        <div className="rounded-2xl bg-night/60 py-3">
          <dt className="text-[11px] text-muted">Jedálniček</dt>
          <dd className={`font-display text-2xl font-black ${adherenceTone(c.adherencePct)}`}>
            {c.adherencePct === null ? "–" : `${c.adherencePct}%`}
          </dd>
        </div>
        <div className="rounded-2xl bg-night/60 py-3">
          <dt className="text-[11px] text-muted">Séria / 30 d</dt>
          <dd className="font-display text-2xl font-black">{c.setsLast30}</dd>
        </div>
        <div className="rounded-2xl bg-night/60 py-3">
          <dt className="text-[11px] text-muted">Tréning</dt>
          <dd className="mt-1.5 text-sm font-semibold">{relativeDay(c.lastTrainingDay, today)}</dd>
        </div>
      </dl>

      <p className={`mt-4 truncate text-sm font-medium ${planState.tone}`}>{planState.text}</p>
      {c.draftPlans > 0 && c.latestPlan?.sentAt && (
        <p className="text-xs text-muted">+ {c.draftPlans} rozpracované</p>
      )}
    </Link>
  );
}

function EmptyState() {
  return (
    <div className="mt-10 rounded-3xl border border-dashed border-line p-10 text-center">
      <p className="font-display text-2xl font-black">Zatiaľ žiadni klienti</p>
      <p className="mx-auto mt-2 max-w-md text-muted">
        Pridaj klienta, pošli mu pozývací kód a jedálničky mu budú chodiť rovno do appky Rejnox.
      </p>
    </div>
  );
}
