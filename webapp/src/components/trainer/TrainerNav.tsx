"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/trener", label: "Klienti", isActive: (p: string) => p === "/trener" || p.startsWith("/trener/klienti") },
  { href: "/trener/kalendar", label: "Kalendár", isActive: (p: string) => p.startsWith("/trener/kalendar") },
  { href: "/trener/spravy", label: "Správy", isActive: (p: string) => p.startsWith("/trener/spravy") },
];

/** Hlavné menu trénera so zvýraznenou aktuálnou sekciou. */
export function TrainerNav({ className = "" }: { className?: string }) {
  const pathname = usePathname();
  return (
    <nav className={`flex items-center gap-1 text-sm font-semibold ${className}`} aria-label="Trénerská zóna">
      {ITEMS.map((item) => {
        const isActive = item.isActive(pathname);
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={isActive ? "page" : undefined}
            className={`relative rounded-full px-3 py-1.5 transition-colors duration-200 ${
              isActive ? "bg-surface-hi text-ink" : "text-muted hover:text-ink"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
