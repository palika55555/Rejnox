import { describe, expect, it } from "vitest";
import { validateLogin, validateRegister } from "./validation";

function form(values: Record<string, string>): FormData {
  const data = new FormData();
  for (const [key, value] of Object.entries(values)) data.set(key, value);
  return data;
}

describe("validateLogin", () => {
  it("prijme platné údaje a e-mail upraví na malé písmená", () => {
    const result = validateLogin(form({ email: "  Jana@Rejnox.SK ", password: "x" }));
    expect(result).toEqual({ ok: true, data: { email: "jana@rejnox.sk", password: "x" } });
  });

  it("vráti chyby pri zlom e-maile a prázdnom hesle", () => {
    const result = validateLogin(form({ email: "jana", password: "" }));
    expect(result).toEqual({
      ok: false,
      errors: { email: "Zadaj platný e-mail.", password: "Zadaj heslo." },
    });
  });
});

describe("validateRegister", () => {
  const valid = { displayName: " Jana ", email: "jana@rejnox.sk", password: "dlheheslo", role: "trainer" };

  it("prijme platné údaje", () => {
    expect(validateRegister(form(valid))).toEqual({
      ok: true,
      data: { displayName: "Jana", email: "jana@rejnox.sk", password: "dlheheslo", role: "trainer" },
    });
  });

  it("odmietne krátke heslo", () => {
    const result = validateRegister(form({ ...valid, password: "kratke" }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.errors.password).toBe("Heslo musí mať 8 až 72 znakov.");
  });

  it("počíta dĺžku hesla v bajtoch ako server", () => {
    // 37 znakov „ž“ = 74 bajtov v UTF-8, teda viac ako 72.
    const result = validateRegister(form({ ...valid, password: "ž".repeat(37) }));
    expect(result.ok).toBe(false);
  });

  it("odmietne prázdne a príliš dlhé meno", () => {
    for (const displayName of ["   ", "a".repeat(61)]) {
      const result = validateRegister(form({ ...valid, displayName }));
      expect(result.ok).toBe(false);
    }
  });

  it("odmietne neznámu rolu", () => {
    const result = validateRegister(form({ ...valid, role: "admin" }));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.errors.role).toBeDefined();
  });
});
