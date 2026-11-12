import { RejnoxMark } from "./RejnoxMark";

export function SiteFooter() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-10 text-sm text-muted sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div className="flex items-center gap-3">
          <RejnoxMark className="w-6" title="" />
          <span>© 2026 Rejnox</span>
        </div>
        <nav aria-label="Odkazy v pätičke" className="flex gap-6">
          <a href="#na-pocitaci" className="hover:text-ink">
            Mobil a počítač
          </a>
          <a href="#pre-trenerov" className="hover:text-ink">
            Pre trénerov
          </a>
          <a href="#otazky" className="hover:text-ink">
            Otázky
          </a>
        </nav>
      </div>
    </footer>
  );
}
