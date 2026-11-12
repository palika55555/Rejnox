import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { Suspense } from "react";
import { logout } from "@/app/(auth)/actions";
import { RejnoxMark } from "@/components/landing/RejnoxMark";
import { WelcomeBurst } from "@/components/motion/WelcomeBurst";
import { currentUser } from "@/lib/session";

export const metadata: Metadata = { title: "Prehľad – Rejnox" };

const upcoming = {
  member: [
    { title: "Jedálničky", text: "Celý týždeň jedál s kalóriami a bielkovinami." },
    { title: "Štatistiky", text: "Objem a rekordy po týždňoch, podľa svalových partií." },
    { title: "Plány od trénera", text: "To isté, čo vidíš v mobile, na veľkej obrazovke." },
  ],
  trainer: [
    { title: "Klienti", text: "Zoznam klientov, ich série a progres na jednom mieste." },
    { title: "Plány", text: "Pripravíš plány pre viacerých klientov naraz." },
    { title: "Jedálničky", text: "Zostavíš klientovi jedálniček na celý týždeň." },
  ],
};

export default function DashboardPage({ searchParams }: PageProps<"/prehlad">) {
  return (
    <div className="min-h-screen">
      <header className="border-b border-line">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link href="/" className="flex items-center gap-3" aria-label="Rejnox, úvodná stránka">
            <RejnoxMark className="w-8" title="" />
            <span className="font-display text-sm font-bold tracking-[0.32em]">REJNOX</span>
          </Link>
          <form action={logout}>
            <button
              type="submit"
              className="rounded-full border border-line px-4 py-2 text-sm font-semibold transition-colors hover:border-accent"
            >
              Odhlásiť sa
            </button>
          </form>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-14 sm:px-6">
        <Suspense fallback={<DashboardSkeleton />}>
          <Dashboard searchParams={searchParams} />
        </Suspense>
      </main>
    </div>
  );
}

async function Dashboard({ searchParams }: Pick<PageProps<"/prehlad">, "searchParams">) {
  const user = await currentUser();
  if (!user) redirect("/prihlasenie");

  // ?vitaj=… pridá prihlásenie alebo registrácia, aby sa pustilo uvítanie.
  const { vitaj } = await searchParams;
  const firstName = user.displayName.split(/\s+/)[0];

  return (
    <>
      {vitaj === "prihlasenie" && <WelcomeBurst title={`Ahoj, ${firstName}`} subtitle="Ideme na to." />}
      {vitaj === "registracia" && (
        <WelcomeBurst title={`Vitaj v Rejnoxe, ${firstName}`} subtitle="Prvý tréning ťa čaká." />
      )}
      <h1 className="font-display text-[clamp(2.2rem,5vw,3.5rem)] leading-tight font-black tracking-[-0.03em]">
        Ahoj, {user.displayName}
      </h1>
      <p className="mt-4 flex flex-wrap items-center gap-3 text-muted">
        <span className="rounded-full border border-accent/50 px-3 py-0.5 text-sm font-semibold text-accent">
          {user.role === "trainer" ? "Tréner" : "Cvičím"}
        </span>
        {user.email}
      </p>

      <section className="mt-12 rounded-3xl border border-line bg-surface/50 p-6 sm:p-8">
        <h2 className="font-display text-xl font-extrabold">Webovú verziu práve staviame</h2>
        <p className="mt-2 max-w-[40rem] text-muted">
          Tvoj účet funguje na webe aj v mobile. Tréningy si zatiaľ zapisuj v appke, sem postupne pribudne:
        </p>
        <ul className="mt-6 grid gap-4 sm:grid-cols-3">
          {upcoming[user.role].map((item) => (
            <li key={item.title} className="rounded-2xl border border-line bg-night p-5">
              <p className="font-semibold">{item.title}</p>
              <p className="mt-1 text-sm leading-relaxed text-muted">{item.text}</p>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}

function DashboardSkeleton() {
  return (
    <div aria-busy="true" aria-label="Načítavam prehľad">
      <div className="h-12 w-72 max-w-full animate-pulse rounded-xl bg-surface-hi" />
      <div className="mt-5 h-6 w-56 animate-pulse rounded-lg bg-surface" />
      <div className="mt-12 h-64 animate-pulse rounded-3xl bg-surface/60" />
    </div>
  );
}
