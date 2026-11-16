import type { Metadata } from "next";
import Link from "next/link";
import { logout } from "@/app/(auth)/actions";
import { RejnoxMark } from "@/components/landing/RejnoxMark";
import { requireTrainer } from "@/lib/trainer";

export const metadata: Metadata = { title: "Trénerská zóna – Rejnox" };

export default async function TrainerLayout({ children }: LayoutProps<"/trener">) {
  const me = await requireTrainer();
  const initials = me.displayName
    .split(/\s+/)
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="min-h-screen bg-night">
      <header className="sticky top-0 z-30 border-b border-line/70 bg-night/85 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-7xl items-center gap-6 px-4 sm:px-6">
          <Link href="/trener" className="flex items-center gap-3" aria-label="Trénerská zóna, klienti">
            <RejnoxMark className="w-8" title="" />
            <span className="hidden font-display text-sm font-bold tracking-[0.32em] sm:inline">REJNOX</span>
            <span className="rounded-full bg-accent/15 px-2.5 py-0.5 text-xs font-semibold text-accent">Tréner</span>
          </Link>
          <nav className="flex items-center gap-1 text-sm font-semibold">
            <Link href="/trener" className="rounded-full px-3 py-1.5 text-muted transition-colors hover:text-ink">
              Klienti
            </Link>
          </nav>
          <div className="ml-auto flex items-center gap-3">
            <span
              className="grid size-9 place-items-center rounded-full bg-surface-hi text-xs font-bold"
              title={me.displayName}
              aria-hidden
            >
              {initials}
            </span>
            <form action={logout}>
              <button
                type="submit"
                className="rounded-full border border-line px-3.5 py-1.5 text-sm font-semibold transition-colors hover:border-accent"
              >
                Odhlásiť
              </button>
            </form>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-10">{children}</main>
    </div>
  );
}
