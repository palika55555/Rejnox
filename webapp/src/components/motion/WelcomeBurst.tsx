"use client";

import { usePathname, useRouter } from "next/navigation";
import { useCallback, useEffect, useState, type CSSProperties } from "react";

// Kotúče od najväčšieho po najmenší, farby svalových partií z appky.
const plates = [
  // Rovnaký pomer výšok ako v appke (118/100/82/64).
  { color: "#FF4D6A", height: 170 },
  { color: "#4D8BFF", height: 144 },
  { color: "#FFC542", height: 118 },
  { color: "#2BD98B", height: 92 },
];

const PLATE_W = 18;
const STEP = 22;
const RIGHT_START = 420;
const LEFT_START = 600 - RIGHT_START - PLATE_W;

type Props = { title: string; subtitle: string };

/** Uvítanie po prihlásení: kotúče dopadnú na činku a tá vyletí hore. */
export function WelcomeBurst({ title, subtitle }: Props) {
  const [done, setDone] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  const finish = useCallback(() => {
    setDone(true);
    // Odstráni ?vitaj z adresy, aby sa animácia pri obnovení stránky neopakovala.
    router.replace(pathname, { scroll: false });
  }, [router, pathname]);

  useEffect(() => {
    const timer = setTimeout(finish, 2900);
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") finish();
    };
    window.addEventListener("keydown", onKey);
    return () => {
      clearTimeout(timer);
      window.removeEventListener("keydown", onKey);
    };
  }, [finish]);

  if (done) return null;

  return (
    <div className="welcome" role="status" aria-live="polite" onClick={finish}>
      <div className="welcome__flash" aria-hidden />
      <div className="welcome__scene">
        <svg viewBox="0 0 600 200" className="welcome__bar" aria-hidden>
          <defs>
            <linearGradient id="welcome-steel" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#C9C6E8" />
              <stop offset="1" stopColor="#6E6A99" />
            </linearGradient>
          </defs>
          <rect x="10" y="93" width="580" height="14" rx="7" fill="url(#welcome-steel)" />
          <rect x={LEFT_START + PLATE_W + 4} y="80" width="12" height="40" rx="3" fill="#8B88B5" />
          <rect x={RIGHT_START - 16} y="80" width="12" height="40" rx="3" fill="#8B88B5" />
          {plates.map((plate, i) => {
            const style = { "--delay": `${0.2 + i * 0.18}s` } as CSSProperties;
            const y = 100 - plate.height / 2;
            return (
              <g key={plate.color}>
                <rect
                  className="welcome__plate"
                  data-side="left"
                  style={style}
                  x={LEFT_START - i * STEP}
                  y={y}
                  width={PLATE_W}
                  height={plate.height}
                  rx="4"
                  fill={plate.color}
                />
                <rect
                  className="welcome__plate"
                  data-side="right"
                  style={style}
                  x={RIGHT_START + i * STEP}
                  y={y}
                  width={PLATE_W}
                  height={plate.height}
                  rx="4"
                  fill={plate.color}
                />
              </g>
            );
          })}
        </svg>
        <h2 className="welcome__title">{title}</h2>
        <p className="welcome__sub">{subtitle}</p>
      </div>
    </div>
  );
}
