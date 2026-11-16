import Link from "next/link";
import { dateTime } from "@/components/trainer/format";
import { InviteButton } from "@/components/trainer/InviteButton";
import { PlanActions } from "@/components/trainer/PlanActions";
import { ProgressCharts } from "@/components/trainer/ProgressCharts";
import { load, requireTrainer } from "@/lib/trainer";
import { clientProgress } from "@/server/clientProgress";
import { listForClient } from "@/server/mealPlans";
import * as trainer from "@/server/trainer";
import { trainerOverview } from "@/server/trainerOverview";
import { requireUuid } from "@/server/validate";

type Client = { id: string; name: string; note: string | null; status: string; hasAccount: boolean };

export default async function ClientPage({ params, searchParams }: PageProps<"/trener/klienti/[id]">) {
  const me = await requireTrainer();
  const { id } = await params;
  const { tab } = await searchParams;
  const showProgress = tab === "progres";

  const { client, plans, progress, overview } = await load(async (db) => {
    const clientId = requireUuid(id);
    // Jedno spojenie s databázou = transakcie len za sebou, nie súbežne.
    const client = (await trainer.clientDetail(db, me.id, clientId)) as unknown as Client;
    const plans = await listForClient(db, me.id, clientId);
    const progress = await clientProgress(db, me.id, clientId);
    const overview = await trainerOverview(db, me.id);
    return { client, plans, progress, overview };
  });
  const isLinked = client.status === "linked";
  const isEnded = client.status === "ended";
  const others = overview.clients.filter((c) => c.id !== client.id && c.status !== "ended").map(({ id, name }) => ({ id, name }));

  return (
    <>
      <Link href="/trener" className="text-sm text-muted transition-colors hover:text-ink">
        ← Všetci klienti
      </Link>

      <header className="mt-4 flex flex-wrap items-start justify-between gap-6">
        <div className="flex items-center gap-4">
          <span className="grid size-16 place-items-center rounded-3xl bg-gradient-to-br from-brand-blue to-brand-violet font-display text-3xl font-black text-white">
            {client.name.slice(0, 1).toUpperCase()}
          </span>
          <div>
            <h1 className="font-display text-[clamp(2rem,4vw,3rem)] leading-none font-black">{client.name}</h1>
            <p className="mt-1.5 text-muted">{client.note ?? "Bez poznámky"}</p>
          </div>
        </div>
        {!isLinked && !isEnded && <InviteButton clientId={client.id} />}
        {isLinked && (
          <span className="rounded-full border border-good/40 bg-good/10 px-3 py-1 text-sm font-semibold text-good">
            Prepojený s appkou
          </span>
        )}
      </header>

      <nav className="mt-8 flex gap-1 border-b border-line" aria-label="Sekcie klienta">
        <TabLink href={`/trener/klienti/${client.id}`} isActive={!showProgress}>
          Jedálničky <span className="ml-1 text-muted">{plans.length}</span>
        </TabLink>
        <TabLink href={`/trener/klienti/${client.id}?tab=progres`} isActive={showProgress}>
          Progres
        </TabLink>
      </nav>

      <div className="mt-6">
        {showProgress ? (
          <ProgressCharts training={progress.training} nutrition={progress.nutrition} today={overview.today} />
        ) : (
          <section>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <p className="text-sm text-muted">
                {isLinked
                  ? "Odoslaný jedálniček klient hneď uvidí v appke a príde mu upozornenie."
                  : "Jedálniček môžeš pripraviť už teraz, odoslať ho pôjde po prepojení s appkou."}
              </p>
              {!isEnded && (
                <Link
                  href={`/trener/klienti/${client.id}/jedalnicek/novy`}
                  className="btn-action rounded-full px-5 py-2.5 text-sm font-bold text-white shadow-lg shadow-accent/20 transition-transform hover:-translate-y-0.5"
                >
                  + Nový jedálniček
                </Link>
              )}
            </div>

            {plans.length === 0 ? (
              <div className="mt-6 rounded-3xl border border-dashed border-line p-10 text-center text-muted">
                Klient zatiaľ nemá žiadny jedálniček.
              </div>
            ) : (
              <ul className="mt-6 grid gap-3">
                {plans.map((p) => (
                  <li key={p.id} className="rounded-3xl border border-line bg-surface p-5">
                    <div className="flex flex-wrap items-start justify-between gap-4">
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h2 className="text-lg font-bold">{p.title}</h2>
                          {p.sentAt ? (
                            <span className="rounded-full bg-good/15 px-2.5 py-0.5 text-xs font-semibold text-good">
                              Odoslaný {dateTime(p.sentAt)}
                            </span>
                          ) : (
                            <span className="rounded-full bg-flame/15 px-2.5 py-0.5 text-xs font-semibold text-flame">
                              Koncept
                            </span>
                          )}
                        </div>
                        <p className="mt-1 text-sm text-muted">
                          {p.itemCount} jedál · ⌀ {p.avgKcal} kcal/deň
                          {p.targets.kcal ? ` · cieľ ${p.targets.kcal} kcal` : ""}
                          {p.targets.proteinG ? ` · ${p.targets.proteinG} g bielkovín` : ""}
                        </p>
                      </div>
                      <PlanActions
                        clientId={client.id}
                        planId={p.id}
                        isSent={p.sentAt !== null}
                        canSend={isLinked && p.itemCount > 0}
                        otherClients={others}
                      />
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}
      </div>
    </>
  );
}

function TabLink({ href, isActive, children }: { href: string; isActive: boolean; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      aria-current={isActive ? "page" : undefined}
      className={`-mb-px border-b-2 px-4 py-2.5 text-sm font-semibold transition-colors ${
        isActive ? "border-accent text-ink" : "border-transparent text-muted hover:text-ink"
      }`}
    >
      {children}
    </Link>
  );
}
