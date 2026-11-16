import { describe, expect, it } from "vitest";
import { nutrition, weekday } from "./clientProgress";
import { HttpError } from "./errors";
import { dayTotals, MAX_ITEMS, parseMealPlan } from "./mealPlans";

const item = (over: Record<string, unknown> = {}) => ({
  day: 0,
  meal: "Raňajky",
  name: "Ovsená kaša",
  amount: "80 g",
  kcal: 350,
  proteinG: 12.34,
  carbsG: 55,
  fatG: 7,
  ...over,
});

function httpError(fn: () => unknown): HttpError {
  try {
    fn();
  } catch (error) {
    if (error instanceof HttpError) return error;
    throw error;
  }
  throw new Error("nečakane prešlo");
}

describe("jedálniček z požiadavky", () => {
  it("prečíta názov, ciele a jedlá, gramy zaokrúhli na desatiny", () => {
    const plan = parseMealPlan({
      title: "  Redukcia  ",
      startsOn: "2026-11-16",
      targets: { kcal: 2200, proteinG: 160 },
      items: [item()],
    });
    expect(plan.title).toBe("Redukcia");
    expect(plan.targets).toEqual({ kcal: 2200, proteinG: 160, carbsG: null, fatG: null });
    expect(plan.items[0]).toMatchObject({ id: null, day: 0, kcal: 350, proteinG: 12.3, amount: "80 g" });
  });

  it("chýbajúce makrá sú nula, prázdny jedálniček je povolený (koncept)", () => {
    const plan = parseMealPlan({ title: "X", items: [item({ proteinG: undefined })] });
    expect(plan.items[0].proteinG).toBe(0);
    expect(parseMealPlan({ title: "Koncept" }).items).toEqual([]);
  });

  it("odmietne zlý deň, záporné kalórie, prázdny názov a priveľa jedál", () => {
    expect(httpError(() => parseMealPlan({ title: "X", items: [item({ day: 7 })] })).code).toBe("invalid_day");
    expect(httpError(() => parseMealPlan({ title: "X", items: [item({ kcal: -1 })] })).code).toBe("invalid_kcal");
    expect(httpError(() => parseMealPlan({ title: " " })).code).toBe("invalid_title");
    const many = Array.from({ length: MAX_ITEMS + 1 }, () => item());
    expect(httpError(() => parseMealPlan({ title: "X", items: many })).code).toBe("invalid_items");
  });

  it("odmietne to isté jedlo dvakrát", () => {
    const id = "00000000-0000-4000-8000-000000000001";
    const error = httpError(() => parseMealPlan({ title: "X", items: [item({ id }), item({ id })] }));
    expect(error.code).toBe("invalid_items");
  });

  it("odmietne nezmyselný kalorický cieľ", () => {
    expect(httpError(() => parseMealPlan({ title: "X", targets: { kcal: 100 } })).code).toBe("invalid_kcal_target");
  });
});

describe("súčet dňa", () => {
  it("sčíta len jedlá daného dňa", () => {
    const items = [
      { day: 0, kcal: 300, proteinG: 20.15, carbsG: 30, fatG: 10 },
      { day: 0, kcal: 500, proteinG: 30, carbsG: 50, fatG: 15 },
      { day: 1, kcal: 999, proteinG: 99, carbsG: 99, fatG: 99 },
    ];
    expect(dayTotals(items, 0)).toEqual({ kcal: 800, proteinG: 50.2, carbsG: 80, fatG: 25 });
    expect(dayTotals(items, 6)).toEqual({ kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 });
  });
});

describe("dodržiavanie jedálnička", () => {
  const today = "2026-11-16"; // pondelok

  it("pondelok je 0, nedeľa 6", () => {
    expect(weekday("2026-11-16")).toBe(0);
    expect(weekday("2026-11-15")).toBe(6);
  });

  it("bez jedálnička: 14 prázdnych dní a žiadne percento", () => {
    const n = nutrition([], [], [], today);
    expect(n.days).toHaveLength(14);
    expect(n.days.at(-1)?.day).toBe(today);
    expect(n.adherencePct).toBeNull();
    expect(n.lastCheckDay).toBeNull();
  });

  it("ráta jedlá z jedálnička platného v daný deň", () => {
    const plans = [{ id: "p1", sentDay: "2026-11-15" }];
    const items = [
      { id: "a", planId: "p1", day: 0, kcal: 400, proteinG: 30 },
      { id: "b", planId: "p1", day: 0, kcal: 600, proteinG: 40 },
      { id: "c", planId: "p1", day: 6, kcal: 500, proteinG: 20 },
    ];
    const checks = [
      { itemId: "a", eatenOn: today },
      { itemId: "c", eatenOn: "2026-11-15" },
    ];
    const n = nutrition(plans, items, checks, today);
    const monday = n.days.at(-1);
    expect(monday).toMatchObject({ plannedMeals: 2, eatenMeals: 1, plannedKcal: 1000, eatenKcal: 400, eatenProteinG: 30 });
    expect(n.days.at(-2)).toMatchObject({ plannedMeals: 1, eatenMeals: 1 });
    // Pred odoslaním jedálnička nič naplánované nebolo.
    expect(n.days.at(-3)).toMatchObject({ planId: null, plannedMeals: 0 });
    expect(n.adherencePct).toBe(67);
    expect(n.lastCheckDay).toBe(today);
  });

  it("novší jedálniček nahradí starší od dňa odoslania", () => {
    const plans = [
      { id: "old", sentDay: "2026-11-01" },
      { id: "new", sentDay: "2026-11-16" },
    ];
    const items = [
      { id: "o", planId: "old", day: 6, kcal: 100, proteinG: 0 },
      { id: "n", planId: "new", day: 0, kcal: 200, proteinG: 0 },
    ];
    const n = nutrition(plans, items, [], today);
    expect(n.days.at(-1)?.planId).toBe("new");
    expect(n.days.at(-2)?.planId).toBe("old");
  });
});
