/**
 * Ďalšie obrazovky appky v telefóne na úvode. Animácie (rast stĺpcov,
 * kreslenie krivky, pády špendlíkov) sa spustia, keď obrazovka dostane
 * triedu .is-active – pozri landing.css.
 */
import { plateColor } from "../exercises";

const weeks = [42, 55, 48, 63, 70, 66, 81, 92];

export function ProgressScreen() {
  const goal = 4;
  const done = 3;
  const r = 30;
  const c = 2 * Math.PI * r;
  return (
    <div className="px-5 pb-6">
      <p className="mt-4 text-xs text-muted">Tvoj progres</p>
      <h3 className="font-display text-2xl font-extrabold tracking-tight">Tento týždeň</h3>

      <div className="mt-4 flex items-center gap-4 rounded-2xl border border-line bg-surface p-4">
        <svg viewBox="0 0 80 80" className="size-20 shrink-0 -rotate-90" aria-hidden>
          <circle cx="40" cy="40" r={r} fill="none" stroke="#1E1B45" strokeWidth="9" />
          <circle
            className="ring-draw"
            cx="40"
            cy="40"
            r={r}
            fill="none"
            stroke="url(#ring-grad)"
            strokeWidth="9"
            strokeLinecap="round"
            strokeDasharray={c}
            style={{ ["--ring-to" as string]: c * (1 - done / goal), ["--ring-from" as string]: c }}
          />
          <defs>
            <linearGradient id="ring-grad" x1="0" x2="1">
              <stop offset="0" stopColor="#5468FF" />
              <stop offset="1" stopColor="#9B5CFF" />
            </linearGradient>
          </defs>
        </svg>
        <div>
          <p className="font-display text-3xl font-black tabular-nums">
            {done}
            <span className="text-lg text-muted">/{goal}</span>
          </p>
          <p className="text-xs text-muted">tréningy do týždenného cieľa</p>
        </div>
      </div>

      <div className="mt-3 rounded-2xl border border-line bg-surface p-4">
        <div className="flex items-baseline justify-between text-xs">
          <span className="font-semibold">Objem po týždňoch</span>
          <span className="text-plate-green">+14 %</span>
        </div>
        <div className="mt-3 flex h-24 items-end gap-1.5" aria-hidden>
          {weeks.map((v, i) => (
            <span
              key={i}
              className="bar-grow flex-1 rounded-t-md"
              style={{
                height: `${v}%`,
                animationDelay: `${120 + i * 60}ms`,
                background: i === weeks.length - 1 ? "linear-gradient(#9B5CFF,#5468FF)" : "#1E1B45",
              }}
            />
          ))}
        </div>
      </div>

      <p className="mt-4 text-xs font-semibold text-muted">Nové rekordy</p>
      <ul className="mt-2 space-y-1.5 text-xs">
        {[
          { name: "Drep", kg: "100 kg", plus: "+5 kg", color: plateColor.nohy },
          { name: "Tlak na lavici", kg: "75 kg", plus: "+2,5 kg", color: plateColor.hrudnik },
        ].map((rec, i) => (
          <li
            key={rec.name}
            className="pop-in flex items-center justify-between rounded-lg bg-surface px-3 py-2.5"
            style={{ animationDelay: `${700 + i * 160}ms` }}
          >
            <span className="flex items-center gap-2">
              <span className="text-sm" aria-hidden>
                🏆
              </span>
              <span className="font-semibold">{rec.name}</span>
              <span className="size-2 rounded-full" style={{ background: rec.color }} />
            </span>
            <span>
              <span className="font-display font-extrabold">{rec.kg}</span>{" "}
              <span className="text-plate-green">{rec.plus}</span>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

const pins = [
  { x: 28, y: 30, d: 200 },
  { x: 68, y: 22, d: 340 },
  { x: 74, y: 58, d: 480 },
  { x: 22, y: 66, d: 620 },
];

export function MapScreen() {
  return (
    <div className="flex h-full flex-col">
      <div className="px-5">
        <p className="mt-4 text-xs text-muted">Fitká v okolí</p>
        <h3 className="font-display text-2xl font-extrabold tracking-tight">Mapa fitiek</h3>
      </div>

      <div className="relative mx-3 mt-3 flex-1 overflow-hidden rounded-3xl border border-line bg-[#0d0c26]">
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 size-full" aria-hidden>
          <path d="M-5 40 C 30 35, 55 52, 105 44" stroke="#1E1B45" strokeWidth="5" fill="none" />
          <path d="M45 -5 C 40 30, 58 70, 50 105" stroke="#1E1B45" strokeWidth="4" fill="none" />
          <path d="M-5 80 L 105 70" stroke="#17153a" strokeWidth="3" fill="none" />
          <path d="M80 -5 L 88 105" stroke="#17153a" strokeWidth="2.5" fill="none" />
          <path d="M10 -5 L 18 105" stroke="#17153a" strokeWidth="2" fill="none" />
          <rect x="56" y="74" width="22" height="16" rx="3" fill="#123826" opacity="0.7" />
          <path className="route-draw" d="M47 52 C 40 45, 34 38, 28 32" stroke="#a48bff" strokeWidth="1.4" strokeDasharray="2 2" fill="none" />
        </svg>

        {/* Poloha používateľa */}
        <span className="absolute top-[52%] left-[47%] -translate-1/2" aria-hidden>
          <span className="me-pulse absolute inset-0 rounded-full bg-brand-blue/40" />
          <span className="relative block size-3.5 rounded-full border-2 border-white bg-brand-blue" />
        </span>

        {pins.map((p, i) => (
          <span
            key={i}
            className="pin-drop absolute -translate-x-1/2 -translate-y-full"
            style={{ left: `${p.x}%`, top: `${p.y}%`, animationDelay: `${p.d}ms` }}
            aria-hidden
          >
            <svg viewBox="0 0 24 32" className="h-7 w-5">
              <path d="M12 0C5.4 0 0 5.3 0 11.8 0 20.6 12 32 12 32s12-11.4 12-20.2C24 5.3 18.6 0 12 0Z" fill={i === 0 ? "#9B5CFF" : "#5468FF"} />
              <circle cx="12" cy="11.5" r="4.5" fill="#fff" />
            </svg>
          </span>
        ))}

        <div className="sheet-up absolute inset-x-2 bottom-2 rounded-2xl border border-line bg-surface/95 p-3 backdrop-blur">
          <div className="flex items-center justify-between">
            <p className="font-semibold">Fitko Aréna</p>
            <p className="text-xs text-plate-yellow">★ 4,7</p>
          </div>
          <p className="mt-0.5 text-xs text-muted">0,8 km · otvorené do 22:00</p>
          <div className="mt-2 flex gap-1.5 text-[11px]">
            <span className="rounded-full bg-surface-hi px-2 py-0.5">Vstup 6 €</span>
            <span className="rounded-full bg-surface-hi px-2 py-0.5">Permanentka 39 €</span>
          </div>
        </div>
      </div>
      <div className="h-6" />
    </div>
  );
}

export function HealthScreen() {
  return (
    <div className="px-5 pb-6">
      <p className="mt-4 text-xs text-muted">Apple Health · Health Connect</p>
      <h3 className="font-display text-2xl font-extrabold tracking-tight">Zdravie</h3>

      <div className="mt-4 rounded-2xl border border-line bg-surface p-4">
        <div className="flex items-center justify-between text-xs">
          <span className="font-semibold">Tep počas tréningu</span>
          <span className="heart-beat text-plate-red" aria-hidden>
            ♥
          </span>
        </div>
        <p className="mt-1 font-display text-4xl font-black tabular-nums">
          142 <span className="text-base font-bold text-muted">bpm</span>
        </p>
        <svg viewBox="0 0 200 50" className="mt-2 h-14 w-full" aria-hidden>
          <path
            className="ecg-draw"
            d="M0 30 H40 L48 30 L54 10 L60 44 L66 30 H100 L108 30 L114 6 L120 46 L126 30 H160 L168 30 L174 12 L180 42 L186 30 H200"
            fill="none"
            stroke="#FF4D6A"
            strokeWidth="2.2"
            strokeLinejoin="round"
            pathLength={1}
          />
        </svg>
      </div>

      <div className="mt-3 grid grid-cols-2 gap-2">
        {[
          { label: "Kroky", value: "8 412", color: "#2BD98B" },
          { label: "Aktívne kcal", value: "526", color: "#FF8A3D" },
          { label: "Pokojový tep", value: "58", color: "#FF4D6A" },
          { label: "Tréning", value: "52 min", color: "#A48BFF" },
        ].map((t, i) => (
          <div
            key={t.label}
            className="pop-in rounded-xl border border-line bg-surface p-3"
            style={{ animationDelay: `${300 + i * 110}ms` }}
          >
            <p className="text-[11px] text-muted">{t.label}</p>
            <p className="mt-0.5 font-display text-lg font-extrabold" style={{ color: t.color }}>
              {t.value}
            </p>
          </div>
        ))}
      </div>

      <div className="notif-drop mt-4 flex items-start gap-3 rounded-2xl bg-surface-hi/90 p-3 text-xs">
        <span className="btn-action grid size-8 shrink-0 place-items-center rounded-lg font-display font-black">R</span>
        <span>
          <span className="block font-semibold">Pripomienka tréningu</span>
          <span className="text-muted">O 18:00 ťa čaká deň nôh. Plán je pripravený.</span>
        </span>
      </div>
      <p className="mt-3 text-[11px] text-muted">Zdravotné údaje sa len čítajú a ostávajú v telefóne.</p>
    </div>
  );
}
