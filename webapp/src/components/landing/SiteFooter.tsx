import Link from "next/link";
import { RejnoxMark } from "./RejnoxMark";

export function SiteFooter() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-10 text-sm text-muted sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div className="flex items-center gap-3">
          <RejnoxMark className="w-6" title="" />
          <span>© 2026 Rejnox</span>
        </div>
        <nav aria-label="Odkazy v pätičke" className="flex flex-wrap gap-x-6 gap-y-2">
          <Link href="/#na-pocitaci" className="hover:text-ink">
            Mobil a počítač
          </Link>
          <Link href="/#pre-trenerov" className="hover:text-ink">
            Pre trénerov
          </Link>
          <Link href="/#otazky" className="hover:text-ink">
            Otázky
          </Link>
          <Link href="/ochrana-osobnych-udajov" className="hover:text-ink">
            Ochrana osobných údajov
          </Link>
          <Link href="/cookies" className="hover:text-ink">
            Cookies
          </Link>
        </nav>
      </div>
    </footer>
  );
}
