import { describe, expect, it } from "vitest";
import { HttpError } from "./errors";
import { MAX_SETS_PER_SYNC, parseSets } from "./training";
import {
  newInviteCode,
  normalizeInviteCode,
  optionalDate,
  validateDisplayName,
  validateEmail,
  validateNewPassword,
  validateRole,
} from "./validate";

const code = (fn: () => unknown) => {
  try {
    fn();
  } catch (error) {
    if (error instanceof HttpError) return `${error.status} ${error.code}`;
    throw error;
  }
  return "ok";
};

describe("účet", () => {
  it("e-mail sa oreže a zmení na malé písmená", () => {
    expect(validateEmail({ email: "  Pavol@Example.SK " })).toBe("pavol@example.sk");
  });

  it("neplatný e-mail sa odmietne", () => {
    for (const email of ["", "bez-zavinaca", "a@b", 42]) {
      expect(code(() => validateEmail({ email }))).toBe("400 invalid_email");
    }
  });

  it("heslo musí mať 8 až 72 bajtov", () => {
    expect(validateNewPassword({ password: "12345678" })).toBe("12345678");
    expect(code(() => validateNewPassword({ password: "1234567" }))).toBe("400 invalid_password");
    expect(code(() => validateNewPassword({ password: "a".repeat(73) }))).toBe("400 invalid_password");
    // 37 znakov "č" = 74 bajtov.
    expect(code(() => validateNewPassword({ password: "č".repeat(37) }))).toBe("400 invalid_password");
  });

  it("meno a rola", () => {
    expect(validateDisplayName({ displayName: " Pavol " })).toBe("Pavol");
    expect(code(() => validateDisplayName({ displayName: "  " }))).toBe("400 invalid_displayName");
    expect(validateRole({})).toBe("member");
    expect(validateRole({ role: "trainer" })).toBe("trainer");
    expect(code(() => validateRole({ role: "admin" }))).toBe("400 invalid_role");
  });
});

describe("pozývací kód", () => {
  it("má tvar XXXX-XXXX a dá sa zadať aj s malými písmenami", () => {
    const fresh = newInviteCode();
    expect(fresh).toMatch(/^[A-Z2-9]{4}-[A-Z2-9]{4}$/);
    expect(normalizeInviteCode(fresh.toLowerCase())).toBe(fresh.replace("-", ""));
    expect(normalizeInviteCode(" k7qm 4xpa ")).toBe("K7QM4XPA");
  });

  it("nezmysel sa odmietne", () => {
    for (const value of ["", "ABCD-EFG", "ABCD-EFG0", 12345678, null]) {
      expect(code(() => normalizeInviteCode(value))).toBe("400 invalid_code");
    }
  });
});

describe("dátum plánu", () => {
  it("prijme len skutočný dátum RRRR-MM-DD", () => {
    expect(optionalDate({ d: "2026-02-28" }, "d")).toBe("2026-02-28");
    expect(optionalDate({}, "d")).toBeNull();
    expect(code(() => optionalDate({ d: "2026-02-30" }, "d"))).toBe("400 invalid_d");
    expect(code(() => optionalDate({ d: "28.2.2026" }, "d"))).toBe("400 invalid_d");
  });
});

describe("parseSets", () => {
  const now = new Date("2026-11-12T12:00:00Z");
  const id = "11111111-1111-4111-8111-111111111111";
  const exerciseId = "00000000-0000-4000-8000-000000000001";
  const valid = { id, exerciseId, reps: 5, weightKg: 100, performedAt: "2026-11-12T10:00:00Z" };

  it("platná séria prejde", () => {
    const { sets, rejected } = parseSets({ sets: [valid] }, now);
    expect(sets).toHaveLength(1);
    expect(sets[0].performedAt.toISOString()).toBe("2026-11-12T10:00:00.000Z");
    expect(rejected.size).toBe(0);
  });

  it("chybné hodnoty sa odmietnu s dôvodom, nie celá dávka", () => {
    const sets = [
      { ...valid, id: "22222222-2222-4222-8222-222222222222", exerciseId: "x" },
      { ...valid, id: "33333333-3333-4333-8333-333333333333", reps: 0 },
      { ...valid, id: "44444444-4444-4444-8444-444444444444", weightKg: -1 },
      { ...valid, id: "55555555-5555-4555-8555-555555555555", performedAt: "2030-01-01T00:00:00Z" },
      { ...valid, id: "nie-uuid" },
      valid,
    ];
    const result = parseSets({ sets }, now);
    expect(result.sets.map((s) => s.id)).toEqual([id]);
    expect(Object.fromEntries(result.rejected)).toEqual({
      "22222222-2222-4222-8222-222222222222": "invalid_exercise",
      "33333333-3333-4333-8333-333333333333": "invalid_reps",
      "44444444-4444-4444-8444-444444444444": "invalid_weight",
      "55555555-5555-4555-8555-555555555555": "invalid_time",
    });
  });

  it("príliš veľká dávka sa odmietne celá", () => {
    const sets = Array.from({ length: MAX_SETS_PER_SYNC + 1 }, () => valid);
    expect(code(() => parseSets({ sets }, now))).toBe("413 too_many_sets");
    expect(code(() => parseSets({}, now))).toBe("400 invalid_sets");
  });
});
