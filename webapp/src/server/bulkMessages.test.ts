import { describe, expect, it } from "vitest";
import { MAX_RECIPIENTS, parseRecipients, personalize } from "./bulkMessages";

const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

describe("hromadná správa", () => {
  it("{meno} nahradí krstným menom, aj viackrát", () => {
    expect(personalize("Ahoj {meno}! {meno}, vidíme sa.", "Jana Nováková")).toBe("Ahoj Jana! Jana, vidíme sa.");
    expect(personalize("Bez mena", "Peter")).toBe("Bez mena");
  });

  it("príjemcov odduplikuje a odmietne prázdny alebo zlý zoznam", () => {
    expect(parseRecipients([id(1), id(1), id(2)])).toEqual([id(1), id(2)]);
    expect(() => parseRecipients([])).toThrow("aspoň jedného");
    expect(() => parseRecipients("x")).toThrow();
    expect(() => parseRecipients(["nie-je-uuid"])).toThrow("Neplatný klient");
    expect(() => parseRecipients(Array.from({ length: MAX_RECIPIENTS + 1 }, (_, i) => id(i)))).toThrow("najviac");
  });
});
