import Link from "next/link";
import { RejnoxMark } from "./RejnoxMark";

const nav = [
  { href: "#na-pocitaci", label: "Mobil a počítač" },
  { href: "#pre-trenerov", label: "Pre trénerov" },
  { href: "#otazky", label: "Otázky" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-30 border-b border-line bg-night/95">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <a href="#" className="flex items-center gap-3" aria-label="Rejnox, na začiatok stránky">
          <RejnoxMark className="w-8" title="" />
          <span className="hidden font-display text-sm font-bold tracking-[0.32em] min-[420px]:inline">REJNOX</span>
        </a>
        <nav aria-label="Hlavná navigácia" className="hidden items-center gap-8 text-sm text-muted md:flex">
          {nav.map((item) => (
            <a key={item.href} href={item.href} className="transition-colors hover:text-ink">
              {item.label}
            </a>
          ))}
        </nav>
        <div className="flex items-center gap-2 whitespace-nowrap sm:gap-4">
          <Link href="/prihlasenie" className="px-2 py-2 text-sm font-semibold transition-colors hover:text-accent">
            Prihlásiť sa
          </Link>
          <Link href="/registracia" className="btn-action rounded-full px-4 py-2 text-sm font-bold text-white">
            Vytvoriť účet
          </Link>
        </div>
      </div>
    </header>
  );
}
