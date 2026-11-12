"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { HealthScreen, MapScreen, ProgressScreen } from "./AppScreens";
import { IPhoneFrame } from "./IPhoneFrame";
import { LogScreen } from "./LogScreen";

type ScreenId = "log" | "progress" | "map" | "health";

const screens: { id: ScreenId; label: string; island: ReactNode }[] = [
  { id: "log", label: "Zápis", island: null },
  { id: "progress", label: "Progres", island: <IslandText icon="🏆" text="Nový rekord · Drep 100 kg" /> },
  { id: "map", label: "Fitká", island: <IslandText icon="📍" text="3 fitká do 2 km" /> },
  { id: "health", label: "Zdravie", island: <IslandText icon="♥" text="Tep 142 bpm" tone="text-plate-red" /> },
];

const AUTO_MS = 4800;
const ISLAND_MS = 2400;

/**
 * Telefón na úvode: obrazovky appky sa samy striedajú, Dynamic Island
 * ukazuje živé aktivity a pri pohybe myši sa telefón jemne nakláňa.
 * Keď návštevník s telefónom pracuje, striedanie sa zastaví.
 */
export function HeroPhone() {
  const [active, setActive] = useState(0);
  const [online, setOnline] = useState(true);
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

  function toggleSignal() {
    setOnline((o) => !o);
    setActive(0);
    setPaused(true);
  }

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
        <IPhoneFrame island={island} signal={{ label: online ? "5G" : "Bez signálu", offline: !online }}>
          {screens.map((s, i) => (
            <div
              key={s.id}
              className={`app-screen ${i === active ? "is-active" : ""}`}
              aria-hidden={i !== active}
              inert={i !== active}
            >
              {s.id === "log" && (
                <LogScreen
                  online={online}
                  onLogged={(text) => flashIsland(<IslandText icon={online ? "✓" : "⏳"} text={text} tone={online ? "text-plate-green" : "text-flame"} />)}
                />
              )}
              {s.id === "progress" && <ProgressScreen />}
              {s.id === "map" && <MapScreen />}
              {s.id === "health" && <HealthScreen />}
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

      <div className="mt-4 flex items-center justify-center gap-3 text-sm text-muted">
        <span id="signal-label">Skús to bez signálu</span>
        <button
          type="button"
          role="switch"
          aria-checked={!online}
          aria-labelledby="signal-label"
          onClick={toggleSignal}
          className={`relative h-6 w-11 rounded-full transition-colors ${online ? "bg-surface-hi" : "bg-flame"}`}
        >
          <span
            className={`absolute top-1 left-1 size-4 rounded-full bg-white transition-transform ${
              online ? "" : "translate-x-5"
            }`}
          />
        </button>
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
          Drep 100 kg · +5 kg
        </span>
      </div>
      <div className="float-card right-[-40%] top-[38%]" style={{ ["--float-delay" as string]: "-2s" }}>
        <span className="size-2.5 rounded-full bg-flame" />
        <span>
          <b className="block text-ink">Bez signálu</b>3 série v telefóne
        </span>
      </div>
      <div className="float-card left-[-36%] bottom-[22%]" style={{ ["--float-delay" as string]: "-4s" }}>
        <span className="font-display text-lg font-black text-plate-green">3/4</span>
        <span>
          <b className="block text-ink">Týždenný cieľ</b>ešte jeden tréning
        </span>
      </div>
    </div>
  );
}
