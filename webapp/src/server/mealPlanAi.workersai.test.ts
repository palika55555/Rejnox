import { describe, expect, it, vi } from "vitest";
import { HttpError } from "./errors";
import { WORKERS_AI_MODEL, generateMealPlan, type AiBinding } from "./mealPlanAi";

const req = {
  clientName: "Jana",
  clientNote: null,
  brief: "redukcia",
  mealsPerDay: 3,
  targets: { kcal: 1800, proteinG: null, carbsG: null, fatG: null },
};

const okPlan = {
  title: "Redukcia",
  note: "",
  targets: { kcal: 1800, proteinG: 130, carbsG: 180, fatG: 60 },
  items: [{ day: 0, meal: "Raňajky", name: "Vajíčka", amount: "3 ks", kcal: 240, proteinG: 18, carbsG: 2, fatG: 16 }],
};

const fakeAi = (impl: (model: string, input: Record<string, unknown>) => Promise<unknown>) => {
  const run = vi.fn(impl);
  return { ai: { run } as AiBinding, run };
};

async function failure(ai: AiBinding): Promise<HttpError> {
  const error = await generateMealPlan(req, ai).catch((e: unknown) => e);
  expect(error).toBeInstanceOf(HttpError);
  return error as HttpError;
}

describe("AI pomocník cez Workers AI", () => {
  it("pošle JSON schému a vráti skontrolovaný jedálniček (odpoveď ako objekt)", async () => {
    const { ai, run } = fakeAi(async () => ({ response: okPlan }));
    const plan = await generateMealPlan(req, ai);
    expect(plan.items).toHaveLength(1);
    expect(plan.targets.kcal).toBe(1800);
    const [model, input] = run.mock.calls[0];
    expect(model).toBe(WORKERS_AI_MODEL);
    expect((input.response_format as { type: string }).type).toBe("json_schema");
    expect(input.max_tokens).toBeGreaterThan(1000);
    expect(JSON.stringify(input.messages)).not.toContain("Jana");
  });

  it("zvládne aj odpoveď ako text s JSON", async () => {
    const { ai } = fakeAi(async () => ({ response: JSON.stringify(okPlan) }));
    expect((await generateMealPlan(req, ai)).items).toHaveLength(1);
  });

  it("model sa dá zmeniť cez AI_MODEL", async () => {
    vi.stubEnv("AI_MODEL", "@cf/test/iny-model");
    try {
      const { ai, run } = fakeAi(async () => ({ response: okPlan }));
      await generateMealPlan(req, ai);
      expect(run.mock.calls[0][0]).toBe("@cf/test/iny-model");
    } finally {
      vi.unstubAllEnvs();
    }
  });

  it("vyčerpaná denná kvóta = 429 so zrozumiteľnou správou", async () => {
    const { ai } = fakeAi(async () => {
      throw new Error("4006: you have used up your daily free allocation of 10,000 neurons");
    });
    expect((await failure(ai)).code).toBe("ai_busy");
  });

  it("nezmyselná odpoveď alebo výpadok = pomocník nedostupný", async () => {
    expect((await failure(fakeAi(async () => ({ response: "toto nie je JSON" })).ai)).code).toBe("ai_unavailable");
    expect((await failure(fakeAi(async () => ({ response: null })).ai)).code).toBe("ai_unavailable");
    expect((await failure(fakeAi(async () => ({ response: { ...okPlan, items: [] } })).ai)).code).toBe("ai_unavailable");
    expect((await failure(fakeAi(async () => { throw new TypeError("fetch failed"); }).ai)).code).toBe("ai_unavailable");
  });
});
