"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { COOKIE_NOTICE_KEY } from "@/lib/legal";

/**
 * Informačná lišta o cookies. Web používa len nevyhnutné cookies, preto
 * nežiada súhlas, len informuje (§ 109 ods. 8 zákona č. 452/2021 Z. z.).
 */
export function CookieNotice() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    let seen = false;
    try {
      seen = localStorage.getItem(COOKIE_NOTICE_KEY) === "1";
    } catch {
      // Bez úložiska lištu ukážeme, zavrie sa len na túto návštevu.
    }
    if (seen) return;
    // Až po úvodnej animácii, aby ju lišta neprekrývala.
    const timer = setTimeout(() => setOpen(true), 2600);
    return () => clearTimeout(timer);
  }, []);

  function close() {
    setOpen(false);
    try {
      localStorage.setItem(COOKIE_NOTICE_KEY, "1");
    } catch {
      // Nič – lišta sa ukáže pri ďalšej návšteve znova.
    }
  }

  if (!open) return null;

  return (
    <div
      role="region"
      aria-label="Informácia o cookies"
      className="cookie-in fixed inset-x-4 bottom-4 z-50 mx-auto max-w-xl rounded-2xl border border-line bg-surface/95 p-4 shadow-[0_30px_80px_-20px_rgb(0_0_0/0.8)] backdrop-blur-md sm:p-5"
    >
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
        <p className="flex-1 text-sm leading-relaxed text-muted">
          <span aria-hidden>🍪 </span>
          Používame len <b className="text-ink">nevyhnutné cookies</b> na prihlásenie a bezpečnosť. Žiadne
          sledovanie ani reklamy.{" "}
          <Link href="/cookies" className="text-accent underline">
            Viac o cookies
          </Link>{" "}
          ·{" "}
          <Link href="/ochrana-osobnych-udajov" className="text-accent underline">
            Ochrana údajov
          </Link>
        </p>
        <button
          type="button"
          onClick={close}
          className="btn-action shrink-0 rounded-full px-5 py-2 text-sm font-bold text-white"
        >
          Rozumiem
        </button>
      </div>
    </div>
  );
}
