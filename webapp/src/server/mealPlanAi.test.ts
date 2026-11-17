import { describe, expect, it } from "vitest";
import { HttpError } from "./errors";
import { buildPrompt, generateMealPlan, toPlanInput, type AiRequest } from "./mealPlanAi";

const req: AiRequest = {
  clientName: "Jana",
  clientNote: "koleno",
  brief: "redukcia, bez laktózy",
  mealsPerDay: 4,
  targets: { kcal: 1900, proteinG: 140, carbsG: null, fatG: null },
};

const item = (over: Record<string, unknown> = {}) => ({
  day: 0,
  meal: "Raňajky",
  name: "Ovsená kaša",
  amount: "80 g",
  kcal: 400,
  proteinG: 15.26,
  carbsG: 60,
  fatG: 8,
  ...over,
});

describe("AI pomocník – zadanie", () => {
  it("obsahuje poznámku, počet jedál, ciele a zadanie, ale nie meno klienta", () => {
    const prompt = buildPrompt(req);
    expect(prompt).not.toContain("Jana");
    expect(prompt).toContain("koleno");
    expect(prompt).toContain("Počet jedál denne: 4");
    expect(prompt).toContain("1900 kcal, 140 g bielkovín");
    expect(prompt).toContain("bez laktózy");
  });

  it("bez cieľov požiada model o návrh", () => {
    const prompt = buildPrompt({ ...req, clientNote: null, targets: { kcal: null, proteinG: null, carbsG: null, fatG: null } });
    expect(prompt).toContain("nezadané – navrhni");
    expect(prompt).not.toContain("Poznámka trénera");
  });
});

describe("AI pomocník – odpoveď na jedálniček", () => {
  it("ciele trénera majú prednosť, chýbajúce doplní model", () => {
    const plan = toPlanInput(
      { title: "Redukcia", note: "Pi vodu.", targets: { kcal: 2500, proteinG: 100, carbsG: 180, fatG: 60 }, items: [item()] },
      req,
    );
    expect(plan.targets).toEqual({ kcal: 1900, proteinG: 140, carbsG: 180, fatG: 60 });
    expect(plan.items[0]).toMatchObject({ day: 0, name: "Ovsená kaša", proteinG: 15.3, id: null });
    expect(plan.note).toBe("Pi vodu.");
  });

  it("zlé položky vyhodí, hodnoty mimo rozsahu oreže", () => {
    const plan = toPlanInput(
      {
        title: "",
        note: "",
        targets: {},
        items: [item({ day: 9 }), item({ name: "  " }), item({ kcal: 99999, proteinG: -5, meal: "" })],
      },
      req,
    );
    expect(plan.title).toBe("Jedálniček – Jana");
    expect(plan.note).toBeNull();
    expect(plan.items).toHaveLength(1);
    expect(plan.items[0]).toMatchObject({ kcal: 5000, proteinG: 0, meal: "Jedlo" });
  });

  it("dlhé texty skráti tak, aby prešli kontrolou jedálnička", () => {
    const plan = toPlanInput(
      { title: "x".repeat(300), note: "", targets: {}, items: [item({ name: "y".repeat(300), amount: "z".repeat(100) })] },
      req,
    );
    expect(plan.title).toHaveLength(120);
    expect(plan.items[0].name).toHaveLength(120);
    expect(plan.items[0].amount).toHaveLength(60);
  });
});

describe("AI pomocník – bez väzby AI", () => {
  it("povie, že pomocník nie je zapnutý", async () => {
    const error = await generateMealPlan(req).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(HttpError);
    expect((error as HttpError).code).toBe("ai_not_configured");
  });
});
