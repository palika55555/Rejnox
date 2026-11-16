import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HttpError } from "./errors";

// Podvrhnuté Gemini SDK: žiadne volanie do siete, odpoveď si určí každý test.
const generateContent = vi.fn();
vi.mock("@google/genai", async (importOriginal) => {
  const real = await importOriginal<typeof import("@google/genai")>();
  return {
    ...real,
    GoogleGenAI: class {
      models = { generateContent };
    },
  };
});

const { ApiError } = await import("@google/genai");
const { DEFAULT_MODEL, generateMealPlan } = await import("./mealPlanAi");

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

const reply = (text: string, finishReason = "STOP") => ({ text, candidates: [{ finishReason }] });

async function failure(): Promise<HttpError> {
  const error = await generateMealPlan(req).catch((e: unknown) => e);
  expect(error).toBeInstanceOf(HttpError);
  return error as HttpError;
}

describe("AI pomocník cez Gemini", () => {
  beforeEach(() => vi.stubEnv("GEMINI_API_KEY", "test-kluc"));
  afterEach(() => {
    vi.unstubAllEnvs();
    generateContent.mockReset();
  });

  it("pošle JSON schému a vráti skontrolovaný jedálniček", async () => {
    generateContent.mockResolvedValue(reply(JSON.stringify(okPlan)));
    const plan = await generateMealPlan(req);
    expect(plan.items).toHaveLength(1);
    expect(plan.targets.kcal).toBe(1800);
    const call = generateContent.mock.calls[0][0];
    expect(call.model).toBe(DEFAULT_MODEL);
    expect(call.config.responseMimeType).toBe("application/json");
    expect(call.config.responseJsonSchema).toBeDefined();
    expect(call.contents).not.toContain("Jana");
  });

  it("model sa dá zmeniť cez GEMINI_MODEL", async () => {
    vi.stubEnv("GEMINI_MODEL", "gemini-4-hydrogen");
    generateContent.mockResolvedValue(reply(JSON.stringify(okPlan)));
    await generateMealPlan(req);
    expect(generateContent.mock.calls[0][0].model).toBe("gemini-4-hydrogen");
  });

  it("vyčerpaný bezplatný limit = 429 so zrozumiteľnou správou", async () => {
    generateContent.mockRejectedValue(new ApiError({ message: "quota", status: 429 }));
    expect((await failure()).code).toBe("ai_busy");
  });

  it("príliš dlhá alebo zablokovaná odpoveď", async () => {
    generateContent.mockResolvedValue(reply("{", "MAX_TOKENS"));
    expect((await failure()).code).toBe("ai_too_long");
    generateContent.mockResolvedValue({ promptFeedback: { blockReason: "SAFETY" }, candidates: [] });
    expect((await failure()).code).toBe("ai_refused");
  });

  it("nezmyselná odpoveď alebo výpadok = pomocník nedostupný", async () => {
    generateContent.mockResolvedValue(reply("toto nie je JSON"));
    expect((await failure()).code).toBe("ai_unavailable");
    generateContent.mockRejectedValue(new TypeError("fetch failed"));
    expect((await failure()).code).toBe("ai_unavailable");
  });
});
