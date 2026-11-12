"use client";

import { useEffect, useState } from "react";
import { INTRO_SEEN_KEY } from "./introSeen";

// Rovnaká geometria ako RejnoxMark (a znak v mobilnej appke).
const LETTER = "M68 0H385A107 107 0 0 1 385 214L400 215L478 305H365L235 155H385A38.5 38.5 0 0 0 385 78H130Z";
const STRIPE = "M150 155H235L135 280Q115 305 85 305H0L100 180Q120 155 150 155Z";

/** Úvodná animácia znaku Rejnox. Klik alebo Esc ju preskočí. */
export function IntroSplash() {
  const [done, setDone] = useState(false);

  useEffect(() => {
    try {
      sessionStorage.setItem(INTRO_SEEN_KEY, "1");
    } catch {
      // Bez úložiska sa úvod ukáže pri každom otvorení, nič viac.
    }
    const timer = setTimeout(() => setDone(true), 2400);
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setDone(true);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      clearTimeout(timer);
      window.removeEventListener("keydown", onKey);
    };
  }, []);

  if (done) return null;

  return (
    <div className="intro" aria-hidden onClick={() => setDone(true)}>
      <div className="intro__glow" />
      <div className="intro__stage">
        <svg viewBox="-8 -8 508 321" className="intro__mark">
          <defs>
            <linearGradient id="intro-stripe" x1="0" y1="0" x2="235" y2="0" gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor="#9B5CFF" />
              <stop offset="1" stopColor="#5B6CFF" />
            </linearGradient>
          </defs>
          <path className="intro__letter" d={LETTER} pathLength={1} />
          <path className="intro__stripe" d={STRIPE} fill="url(#intro-stripe)" />
        </svg>
        <p className="intro__word">REJNOX</p>
        <p className="intro__tag">Lepší pohyb, zdravší ty.</p>
      </div>
    </div>
  );
}
