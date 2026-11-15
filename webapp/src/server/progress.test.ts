import { describe, expect, it } from "vitest";
import { type DayRow, mondayOf, summarize } from "./progress";

const squat = "00000000-0000-4000-8000-000000000001";
const bench = "00000000-0000-4000-8000-000000000004";

function row(day: string, exerciseId: string, over: Partial<DayRow> = {}): DayRow {
  const isSquat = exerciseId === squat;
  return {
    day,
    exerciseId,
    name: isSquat ? "Drep s činkou" : "Bench press",
    muscleGroup: isSquat ? "nohy" : "hrudnik",
    sets: 3,
    volumeKg: 1000,
    bestKg: 100,
    e1rmKg: 120,
    ...over,
  };
}

describe("pondelok týždňa", () => {
  it("nedeľa patrí k pondelku pred ňou", () => {
    expect(mondayOf("2026-11-15")).toBe("2026-11-09");
  });

  it("pondelok je sám sebe pondelkom", () => {
    expect(mondayOf("2026-11-16")).toBe("2026-11-16");
  });
});

describe("prehľad progresu", () => {
  const today = "2026-11-15";

  it("bez sérií: nuly a 12 prázdnych týždňov", () => {
    const p = summarize([], today);
    expect(p.totals).toEqual({ trainingDays: 0, sets: 0, volumeKg: 0 });
    expect(p.month).toEqual({ days: 0, sets: 0, volumeKg: 0, prevVolumeKg: 0 });
    expect(p.weeks).toHaveLength(12);
    expect(p.weeks.at(-1)).toEqual({ start: "2026-11-09", days: 0, sets: 0, volumeKg: 0 });
    expect(p.weeks[0].start).toBe("2026-08-24");
    expect(p.exercises).toEqual([]);
    expect(p.muscles).toEqual([]);
  });

  it("sčíta dni, série a objem; mesiac porovná s mesiacom pred ním", () => {
    const p = summarize(
      [
        row("2026-09-01", squat, { volumeKg: 500 }), // pred 2 mesiacmi: ráta sa len do súčtu
        row("2026-10-10", squat, { volumeKg: 800 }), // predošlý mesiac
        row("2026-11-14", squat),
        row("2026-11-14", bench, { sets: 2, volumeKg: 400 }),
        row("2026-11-15", bench, { sets: 4, volumeKg: 600 }),
      ],
      today,
    );
    expect(p.totals).toEqual({ trainingDays: 4, sets: 15, volumeKg: 3300 });
    expect(p.month).toEqual({ days: 2, sets: 9, volumeKg: 2000, prevVolumeKg: 800 });
    expect(p.weeks.at(-1)).toEqual({ start: "2026-11-09", days: 2, sets: 9, volumeKg: 2000 });
    expect(p.muscles).toEqual([
      { muscleGroup: "hrudnik", sets: 6 },
      { muscleGroup: "nohy", sets: 3 },
    ]);
  });

  it("cvik: rekord, odhad maxima, východisko a krivka po dňoch", () => {
    const p = summarize(
      [
        row("2026-10-01", squat, { bestKg: 80, e1rmKg: 96 }),
        row("2026-10-08", squat, { bestKg: 90, e1rmKg: null }),
        row("2026-10-15", squat, { bestKg: 85, e1rmKg: 110.04 }),
      ],
      today,
    );
    expect(p.exercises).toEqual([
      {
        exerciseId: squat,
        name: "Drep s činkou",
        muscleGroup: "nohy",
        bestKg: 90,
        bestE1rmKg: 110,
        firstKg: 80,
        lastDay: "2026-10-15",
        days: 3,
        trend: [
          { day: "2026-10-01", kg: 80 },
          { day: "2026-10-08", kg: 90 },
          { day: "2026-10-15", kg: 85 },
        ],
      },
    ]);
  });

  it("cviky zoradí od naposledy odcvičeného, krivka má najviac 12 bodov", () => {
    const days = Array.from({ length: 15 }, (_, i) => `2026-10-${String(i + 1).padStart(2, "0")}`);
    const p = summarize([...days.map((d) => row(d, squat)), row("2026-11-01", bench)], today);
    expect(p.exercises.map((e) => e.exerciseId)).toEqual([bench, squat]);
    expect(p.exercises[1].trend).toHaveLength(12);
    expect(p.exercises[1].trend[0].day).toBe("2026-10-04");
  });
});
