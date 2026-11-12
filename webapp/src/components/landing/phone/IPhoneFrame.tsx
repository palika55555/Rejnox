import type { ReactNode } from "react";

type Props = {
  children: ReactNode;
  /** Obsah Dynamic Islandu, keď sa roztiahne (živá aktivita). Null = zbalený. */
  island?: ReactNode;
  /** Text vpravo v stavovom riadku. */
  signal: { label: string; offline: boolean };
  className?: string;
};

/**
 * Telefón v štýle iPhone 18 Pro: titánový rám, tenké okraje, menší
 * Dynamic Island a bočné tlačidlá (akcia, hlasitosť, zapnutie, ovládanie
 * fotoaparátu). Čisto CSS, bez obrázkov.
 */
export function IPhoneFrame({ children, island, signal, className = "" }: Props) {
  return (
    <div className={`iphone ${className}`}>
      {/* Bočné tlačidlá */}
      <span aria-hidden className="iphone__btn iphone__btn--action" />
      <span aria-hidden className="iphone__btn iphone__btn--vol-up" />
      <span aria-hidden className="iphone__btn iphone__btn--vol-down" />
      <span aria-hidden className="iphone__btn iphone__btn--power" />
      <span aria-hidden className="iphone__btn iphone__btn--camera" />

      <div className="iphone__body">
        <div className="iphone__screen">
          {/* Stavový riadok */}
          <div className="relative z-20 flex h-11 items-center justify-between px-7 pt-1 text-[12px] font-semibold">
            <span className="tabular-nums">18:42</span>
            <span className={`flex items-center gap-1.5 ${signal.offline ? "text-flame" : ""}`}>
              <SignalBars off={signal.offline} />
              <span className="text-[11px]">{signal.label}</span>
              <Battery />
            </span>
          </div>

          {/* Dynamic Island */}
          <div aria-hidden={!island} className={`iphone__island ${island ? "is-open" : ""}`}>
            <span className="iphone__lens" />
            <div className="iphone__island-content" role="status">
              {island}
            </div>
          </div>

          <div className="relative h-[calc(100%-2.75rem)]">{children}</div>

          {/* Domovská lišta */}
          <span aria-hidden className="iphone__home" />
          <span aria-hidden className="iphone__glare" />
        </div>
      </div>
    </div>
  );
}

function SignalBars({ off }: { off: boolean }) {
  return (
    <svg viewBox="0 0 17 11" className="h-[10px] w-[16px]" aria-hidden>
      {[0, 1, 2, 3].map((i) => (
        <rect
          key={i}
          x={i * 4.5}
          y={8 - i * 2.6}
          width="3"
          height={3 + i * 2.6}
          rx="0.8"
          fill="currentColor"
          opacity={off && i > 0 ? 0.25 : 1}
        />
      ))}
    </svg>
  );
}

function Battery() {
  return (
    <svg viewBox="0 0 27 12" className="h-[11px] w-[24px]" aria-hidden>
      <rect x="0.5" y="0.5" width="22" height="11" rx="3.2" fill="none" stroke="currentColor" opacity="0.4" />
      <rect x="2" y="2" width="15" height="8" rx="2" fill="currentColor" />
      <rect x="24" y="4" width="2" height="4" rx="1" fill="currentColor" opacity="0.4" />
    </svg>
  );
}
