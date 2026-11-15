"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { IPhoneFrame } from "./IPhoneFrame";

type ScreenId = "home" | "workout" | "chat" | "calendar" | "progress";

/** Skutočné obrazovky appky (snímky z public/app, 390×844 @2x). */
const screens: { id: ScreenId; label: string; alt: string; island: ReactNode }[] = [
  {
    id: "home",
    label: "Dnes",
    alt: "Domovská obrazovka: dnešný tréning od trénera, týždenný cieľ a séria dní",
    island: <IslandText icon="🔥" text="Dnešný plán od trénera" />,
  },
  {
    id: "workout",
    label: "Tréning",
    alt: "Zápis série: cvik, opakovania a váha veľkými tlačidlami",
    island: <IslandText icon="✓" text="Séria uložená · 8 × 70 kg" tone="text-good" />,
  },
  {
    id: "chat",
    label: "Chat",
    alt: "Chat s trénerom: správy o dnešnom pláne",
    island: <IslandText icon="💬" text="Martin: 4×8 na 70 kg" />,
  },
  {
    id: "calendar",
    label: "Kalendár",
    alt: "Kalendár tréningov u trénera s voľnými termínmi",
    island: <IslandText icon="📅" text="Zajtra 18:00 · Osobný tréning" />,
  },
  {
    id: "progress",
    label: "Progres",
    alt: "Progres: objem po týždňoch a osobné rekordy",
    island: <IslandText icon="🏆" text="Nový rekord · Drep 75 kg" tone="text-flame" />,
  },
];

const AUTO_MS = 4800;
const ISLAND_MS = 2400;

/**
 * Telefón na úvode: skutočné obrazovky appky sa samy striedajú, Dynamic Island
 * ukazuje živé aktivity a pri pohybe myši sa telefón jemne nakláňa.
 * Keď návštevník s telefónom pracuje, striedanie sa zastaví.
 */
export function HeroPhone() {
  const [active, setActive] = useState(0);
  const [paused, setPaused] = useState(false);
  const [visible, setVisible] = useState(true);
  const [island, setIsland] = useState<ReactNode>(null);
  const tiltRef = useRef<HTMLDivElement>(null);
  const islandTimer = useRef<ReturnType<typeof setTimeout>>(undefined);

  const flashIsland = useCallback((content: ReactNode) => {
    clearTimeout(islandTimer.current);
    setIsland(content);
    if (content) islandTimer.current = setTimeout(() => setIsland(null), ISLAND_MS);
  }, []);

  const show = useCallback(
    (index: number) => {
      setActive(index);
      // Island sa roztiahne chvíľu po prechode obrazovky.
      setTimeout(() => flashIsland(screens[index].island), 450);
    },
    [flashIsland],
  );

  // Automatické striedanie obrazoviek (nie pri zníženom pohybe ani mimo obrazovky).
  useEffect(() => {
    if (paused || !visible || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timer = setTimeout(() => show((active + 1) % screens.length), AUTO_MS);
    return () => clearTimeout(timer);
  }, [active, paused, visible, show]);

  // Keď hero nie je vidno alebo je karta na pozadí, animácie v ňom stoja (šetrí GPU).
  useEffect(() => {
    const section = tiltRef.current?.closest("section");
    if (!section) return;
    let inView = true;
    const update = () => {
      const on = inView && document.visibilityState === "visible";
      setVisible(on);
      if (on) section.removeAttribute("data-paused");
      else section.setAttribute("data-paused", "");
    };
    const observer = new IntersectionObserver(([entry]) => {
      inView = entry.isIntersecting;
      update();
    });
    observer.observe(section);
    document.addEventListener("visibilitychange", update);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", update);
    };
  }, []);

  useEffect(() => () => clearTimeout(islandTimer.current), []);

  // Náklon za myšou: len jemné ukazovacie zariadenia a bez zníženého pohybu.
  useEffect(() => {
    const el = tiltRef.current;
    const section = el?.closest("section");
    if (!el || !section) return;
    if (!matchMedia("(pointer: fine)").matches || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let frame = 0;
    function onMove(e: PointerEvent) {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const rect = el!.getBoundingClientRect();
        const x = (e.clientX - (rect.left + rect.width / 2)) / window.innerWidth;
        const y = (e.clientY - (rect.top + rect.height / 2)) / window.innerHeight;
        el!.style.setProperty("--tilt-y", `${(x * 16).toFixed(2)}deg`);
        el!.style.setProperty("--tilt-x", `${(-y * 10).toFixed(2)}deg`);
      });
    }
    function onLeave() {
      el!.style.setProperty("--tilt-y", "0deg");
      el!.style.setProperty("--tilt-x", "0deg");
    }
    section.addEventListener("pointermove", onMove);
    section.addEventListener("pointerleave", onLeave);
    return () => {
      cancelAnimationFrame(frame);
      section.removeEventListener("pointermove", onMove);
      section.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  return (
    <div className="hero-phone relative mx-auto w-full max-w-[21rem]">
      <FloatingCards />

      <div
        className="tilt"
        ref={tiltRef}
        onPointerEnter={() => setPaused(true)}
        onPointerLeave={() => setPaused(false)}
        onFocus={() => setPaused(true)}
        onBlur={() => setPaused(false)}
      >
        <IPhoneFrame island={island} signal={{ label: "5G", offline: false }}>
          {screens.map((s, i) => (
            <div
              key={s.id}
              className={`app-screen ${i === active ? "is-active" : ""}`}
              aria-hidden={i !== active}
              inert={i !== active}
            >
              <Image
                src={`/app/${s.id}.webp`}
                alt={s.alt}
                fill
                sizes="(min-width: 640px) 21rem, 80vw"
                priority={i === 0}
                className="object-cover object-top"
              />
            </div>
          ))}
        </IPhoneFrame>
      </div>

      <div className="mt-6 flex justify-center gap-1.5" role="tablist" aria-label="Obrazovky appky">
        {screens.map((s, i) => (
          <button
            key={s.id}
            type="button"
            role="tab"
            aria-selected={i === active}
            onClick={() => {
              show(i);
              setPaused(true);
            }}
            className={`screen-tab rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
              i === active ? "bg-surface-hi text-ink" : "text-muted hover:text-ink"
            } ${i === active && !paused ? "is-running" : ""}`}
            style={{ ["--auto-ms" as string]: `${AUTO_MS}ms` }}
          >
            {s.label}
          </button>
        ))}
      </div>

    </div>
  );
}

function IslandText({ icon, text, tone = "text-accent" }: { icon: string; text: string; tone?: string }) {
  return (
    <span className="flex w-full items-center justify-between gap-3 px-1">
      <span className={`text-sm ${tone}`} aria-hidden>
        {icon}
      </span>
      <span className="truncate text-[11px] font-semibold">{text}</span>
      <span className={`size-1.5 shrink-0 rounded-full bg-current ${tone}`} aria-hidden />
    </span>
  );
}

/** Plávajúce karty okolo telefónu (len na širších obrazovkách). */
function FloatingCards() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 hidden sm:block">
      <div className="float-card left-[-46%] top-[14%]" style={{ ["--float-delay" as string]: "0s" }}>
        <span className="text-lg">🏆</span>
        <span>
          <b className="block text-ink">Nový rekord</b>
          Drep 75 kg · +20 kg
        </span>
      </div>
      <div className="float-card right-[-40%] top-[38%]" style={{ ["--float-delay" as string]: "-2s" }}>
        <span className="text-lg">💬</span>
        <span>
          <b className="block text-ink">Správa od trénera</b>Drep 4×8 na 70 kg
        </span>
      </div>
      <div className="float-card left-[-36%] bottom-[22%]" style={{ ["--float-delay" as string]: "-4s" }}>
        <span className="font-display text-lg font-black text-good">5/3</span>
        <span>
          <b className="block text-ink">Týždenný cieľ</b>splnený, 4 dni v rade
        </span>
      </div>
    </div>
  );
}
