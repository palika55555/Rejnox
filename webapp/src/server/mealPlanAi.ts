import Anthropic from "@anthropic-ai/sdk";
import { HttpError } from "./errors";
import { MAX_ITEMS, parseMealPlan, type MealPlanInput, type Targets } from "./mealPlans";

/** AI pomocník trénera: návrh jedálnička na týždeň (tréner ho pred odoslaním skontroluje). */

export const MODEL = "claude-opus-5-5";

/** Čo tréner zadá pomocníkovi. */
export type AiRequest = {
  clientName: string;
  clientNote: string | null;
  /** Voľný text: cieľ, alergie, čo klient nejí, rozpočet, kuchyňa… */
  brief: string;
  mealsPerDay: number;
  targets: Targets;
};

const unavailable = () =>
  new HttpError(503, "ai_unavailable", "AI pomocník teraz nie je k dispozícii. Skús to o chvíľu.");

/** Štruktúra odpovede, ktorú model musí dodržať (makrá v gramoch, dni 0 = pondelok). */
export const RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["title", "note", "targets", "items"],
  properties: {
    title: { type: "string", description: "Krátky názov jedálnička, najviac 60 znakov." },
    note: { type: "string", description: "1–3 vety pre klienta (pitný režim, príprava). Môže byť prázdne." },
    targets: {
      type: "object",
      additionalProperties: false,
      required: ["kcal", "proteinG", "carbsG", "fatG"],
      properties: {
        kcal: { type: "integer" },
        proteinG: { type: "integer" },
        carbsG: { type: "integer" },
        fatG: { type: "integer" },
      },
    },
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["day", "meal", "name", "amount", "kcal", "proteinG", "carbsG", "fatG"],
        properties: {
          day: { type: "integer", description: "0 = pondelok … 6 = nedeľa" },
          meal: { type: "string", description: "Raňajky, Desiata, Obed, Olovrant, Večera, Pred tréningom alebo Po tréningu" },
          name: { type: "string" },
          amount: { type: "string", description: "Množstvo, napr. „150 g kuracích pŕs, 80 g ryže“" },
          kcal: { type: "integer" },
          proteinG: { type: "number" },
          carbsG: { type: "number" },
          fatG: { type: "number" },
        },
      },
    },
  },
} as const;

const SYSTEM = `Si výživový asistent fitness trénera v slovenskej appke Rejnox.
Navrhuješ týždenný jedálniček pre klienta trénera. Tréner ho pred odoslaním skontroluje a upraví.

Pravidlá:
- Píš po slovensky, jedlá bežne dostupné na Slovensku, jednoduchá príprava.
- Každý deň (0 = pondelok … 6 = nedeľa) má presne zadaný počet jedál; jedlá v dni zoraď chronologicky.
- Kalórie a makrá uvádzaj realisticky pre uvedené množstvo; denný súčet nech je do ±5 % od cieľa.
- Dni nech sa rozumne striedajú, ale opakovanie surovín je v poriadku (jednoduchší nákup).
- Dodrž alergie a obmedzenia zo zadania. Ak niečo nie je jasné, zvoľ bezpečnejšiu možnosť.
- Ak tréner ciele nezadal, odhadni rozumné ciele zo zadania a uveď ich v "targets".
- Nedávaj zdravotné rady ani diagnózy; jedálniček nie je náhrada za lekára.`;

/** Text požiadavky pre model (bez osobných údajov okrem toho, čo zadal tréner). */
export function buildPrompt(req: AiRequest): string {
  const t = req.targets;
  const targets = [
    t.kcal ? `${t.kcal} kcal` : null,
    t.proteinG ? `${t.proteinG} g bielkovín` : null,
    t.carbsG ? `${t.carbsG} g sacharidov` : null,
    t.fatG ? `${t.fatG} g tukov` : null,
  ].filter(Boolean);
  return [
    `Klient: ${req.clientName}`,
    req.clientNote ? `Poznámka trénera ku klientovi: ${req.clientNote}` : null,
    `Počet jedál denne: ${req.mealsPerDay}`,
    `Denné ciele: ${targets.length ? targets.join(", ") : "nezadané – navrhni"}`,
    "",
    "Zadanie od trénera:",
    req.brief || "(bez ďalších požiadaviek)",
  ]
    .filter((line) => line !== null)
    .join("\n");
}

type RawItem = { day: number; meal: string; name: string; amount: string; kcal: number; proteinG: number; carbsG: number; fatG: number };
type RawPlan = { title: string; note: string; targets: Record<string, number>; items: RawItem[] };

const clampInt = (n: unknown, min: number, max: number) =>
  typeof n === "number" && Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : null;

/**
 * Odpoveď modelu → jedálniček, ktorý prejde rovnakou kontrolou ako ručne zadaný.
 * Hodnoty mimo rozsahu sa orežú, texty skrátia; nezmyselné položky vypadnú.
 */
export function toPlanInput(raw: RawPlan, req: AiRequest): MealPlanInput {
  const items = (Array.isArray(raw.items) ? raw.items : [])
    .filter((i) => Number.isInteger(i?.day) && i.day >= 0 && i.day <= 6 && typeof i.name === "string" && i.name.trim())
    .slice(0, MAX_ITEMS)
    .map((i) => ({
      day: i.day,
      meal: (String(i.meal ?? "").trim() || "Jedlo").slice(0, 40),
      name: i.name.trim().slice(0, 120),
      amount: String(i.amount ?? "").trim().slice(0, 60) || null,
      kcal: clampInt(i.kcal, 0, 5000) ?? 0,
      proteinG: Math.min(500, Math.max(0, Number(i.proteinG) || 0)),
      carbsG: Math.min(1000, Math.max(0, Number(i.carbsG) || 0)),
      fatG: Math.min(500, Math.max(0, Number(i.fatG) || 0)),
    }));
  const t = raw.targets ?? {};
  return parseMealPlan({
    title: (String(raw.title ?? "").trim() || `Jedálniček – ${req.clientName}`).slice(0, 120),
    note: String(raw.note ?? "").trim().slice(0, 1000) || null,
    targets: {
      kcal: req.targets.kcal ?? clampInt(t.kcal, 500, 10000),
      proteinG: req.targets.proteinG ?? clampInt(t.proteinG, 0, 1000),
      carbsG: req.targets.carbsG ?? clampInt(t.carbsG, 0, 2000),
      fatG: req.targets.fatG ?? clampInt(t.fatG, 0, 1000),
    },
    items,
  });
}

function client(): Anthropic {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new HttpError(503, "ai_not_configured", "AI pomocník ešte nie je zapnutý (chýba kľúč ANTHROPIC_API_KEY).");
  }
  // Pri výpadku jedna rýchla opakovaná požiadavka stačí, tréner môže skúsiť znova.
  return new Anthropic({ maxRetries: 1, timeout: 5 * 60 * 1000 });
}

/** Zavolá model a vráti návrh jedálnička (neuložený). */
export async function generateMealPlan(req: AiRequest): Promise<MealPlanInput> {
  let message: Anthropic.Beta.BetaMessage;
  try {
    message = await client()
      .beta.messages.stream({
        model: MODEL,
        max_tokens: 32000,
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: SYSTEM,
        output_config: { effort: "low", format: { type: "json_schema", schema: RESPONSE_SCHEMA } },
        messages: [{ role: "user", content: buildPrompt(req) }],
      })
      .finalMessage();
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      throw new HttpError(429, "ai_busy", "AI pomocník je práve vyťažený. Skús to o minútu.");
    }
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      console.error("AI pomocník: neplatný kľúč alebo prístup", error.status);
      throw unavailable();
    }
    if (error instanceof Anthropic.APIError) {
      console.error("AI pomocník: chyba API", error.status);
      throw unavailable();
    }
    throw error;
  }

  if (message.stop_reason === "refusal") {
    throw new HttpError(422, "ai_refused", "AI pomocník toto zadanie nespracuje. Skús ho preformulovať.");
  }
  if (message.stop_reason === "max_tokens") {
    throw new HttpError(422, "ai_too_long", "Návrh bol príliš dlhý. Skús menej jedál denne.");
  }
  const text = message.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
  let raw: RawPlan;
  try {
    raw = JSON.parse(text) as RawPlan;
  } catch {
    throw unavailable();
  }
  const plan = toPlanInput(raw, req);
  if (plan.items.length === 0) throw unavailable();
  return plan;
}

