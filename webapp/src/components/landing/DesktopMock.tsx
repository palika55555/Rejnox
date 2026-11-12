import { groupLabel, plateColor, type MuscleGroup } from "./exercises";

/** Objem v tonách za týždeň podľa partie – ukážkové dáta. */
const weeks: Record<MuscleGroup, number>[] = [
  { nohy: 3.1, chrbat: 2.2, hrudnik: 1.6, ramena: 0.8 },
  { nohy: 3.4, chrbat: 2.0, hrudnik: 1.8, ramena: 0.9 },
  { nohy: 2.6, chrbat: 2.4, hrudnik: 1.7, ramena: 1.0 },
  { nohy: 3.8, chrbat: 2.5, hrudnik: 1.9, ramena: 0.9 },
  { nohy: 3.6, chrbat: 2.7, hrudnik: 2.1, ramena: 1.1 },
  { nohy: 4.0, chrbat: 2.6, hrudnik: 2.0, ramena: 1.2 },
  { nohy: 4.3, chrbat: 2.9, hrudnik: 2.3, ramena: 1.2 },
  { nohy: 4.6, chrbat: 3.1, hrudnik: 2.4, ramena: 1.3 },
];

const order: MuscleGroup[] = ["nohy", "chrbat", "hrudnik", "ramena"];

const meals = [
  { name: "Raňajky", food: "Ovsená kaša, tvaroh, čučoriedky", kcal: 540, protein: 38 },
  { name: "Obed", food: "Kuracie prsia, ryža, brokolica", kcal: 720, protein: 52 },
  { name: "Olovrant", food: "Grécky jogurt, orechy", kcal: 310, protein: 22 },
  { name: "Večera", food: "Losos, zemiaky, šalát", kcal: 650, protein: 41 },
];

const records = [
  { exercise: "Drep", value: "120 kg", group: "nohy" as MuscleGroup },
  { exercise: "Tlak na lavici", value: "85 kg", group: "hrudnik" as MuscleGroup },
  { exercise: "Príťahy v predklone", value: "75 kg", group: "chrbat" as MuscleGroup },
];

export function DesktopMock() {
  const max = Math.max(...weeks.map((w) => order.reduce((sum, g) => sum + w[g], 0)));
  const chartH = 150;
  const barW = 26;
  const step = 40;
  const totalKcal = meals.reduce((s, m) => s + m.kcal, 0);
  const totalProtein = meals.reduce((s, m) => s + m.protein, 0);

  return (
    <div
      className="rounded-2xl border border-line bg-surface p-3 shadow-[0_30px_100px_-40px_rgb(84_104_255/0.5)]"
      aria-label="Ukážka webovej verzie Rejnox"
      role="img"
    >
      <div className="grid gap-3 rounded-xl bg-night p-4 sm:p-5 md:grid-cols-[1.25fr_1fr]">
        <div className="rounded-xl border border-line p-4">
          <div className="flex items-baseline justify-between gap-3">
            <p className="font-display text-sm font-extrabold">Objem za 8 týždňov</p>
            <p className="text-xs text-plate-green">+48 %</p>
          </div>
          <svg viewBox={`0 0 ${step * weeks.length} ${chartH + 20}`} className="mt-4 w-full" aria-hidden>
            {weeks.map((w, i) => {
              let y = chartH;
              return (
                <g key={i}>
                  {order.map((g) => {
                    const h = (w[g] / max) * chartH;
                    y -= h;
                    return (
                      <rect
                        key={g}
                        x={i * step + (step - barW) / 2}
                        y={y + 1}
                        width={barW}
                        height={Math.max(0, h - 2)}
                        rx="3"
                        fill={plateColor[g]}
                        opacity={i === weeks.length - 1 ? 1 : 0.55}
                      />
                    );
                  })}
                  <text
                    x={i * step + step / 2}
                    y={chartH + 16}
                    textAnchor="middle"
                    fontSize="10"
                    fill="#8B88B5"
                  >
                    {i + 1}.
                  </text>
                </g>
              );
            })}
          </svg>
          <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
            {order.map((g) => (
              <li key={g} className="flex items-center gap-1.5">
                <span className="size-2 rounded-full" style={{ background: plateColor[g] }} />
                {groupLabel[g]}
              </li>
            ))}
          </ul>
        </div>

        <div className="grid gap-3">
          <div className="rounded-xl border border-line p-4">
            <p className="font-display text-sm font-extrabold">Jedálniček na utorok</p>
            <table className="mt-3 w-full text-left text-xs">
              <tbody>
                {meals.map((m) => (
                  <tr key={m.name} className="border-t border-line first:border-t-0">
                    <td className="py-1.5 pr-2 align-top font-semibold">{m.name}</td>
                    <td className="py-1.5 pr-2 align-top text-muted">{m.food}</td>
                    <td className="py-1.5 text-right align-top tabular-nums">{m.kcal}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-2 flex justify-between border-t border-line pt-2 text-xs">
              <span className="text-muted">Bielkoviny {totalProtein} g</span>
              <span className="font-bold text-flame tabular-nums">{totalKcal} kcal</span>
            </p>
          </div>

          <div className="rounded-xl border border-line p-4">
            <p className="font-display text-sm font-extrabold">Osobné rekordy</p>
            <ul className="mt-2 space-y-1.5 text-xs">
              {records.map((r) => (
                <li key={r.exercise} className="flex items-center justify-between">
                  <span className="flex items-center gap-2">
                    <span className="size-2 rounded-full" style={{ background: plateColor[r.group] }} />
                    {r.exercise}
                  </span>
                  <span className="font-bold tabular-nums">{r.value}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
