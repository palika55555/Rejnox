import { describe, expect, it } from "vitest";
import { checkChallengeDates } from "./communityMeet";
import { parseBuddy, parseChallenge, parseEvent, requireFutureTime } from "./communityRoutes";
import { HttpError } from "./errors";

const now = Date.parse("2026-11-16T12:00:00Z");
const inHours = (h: number) => new Date(now + h * 3600_000).toISOString();

function code(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    if (e instanceof HttpError) return e.code;
    throw e;
  }
  return undefined;
}

describe("requireFutureTime", () => {
  it("prijme čas o hodinu", () => {
    expect(requireFutureTime({ t: inHours(1) }, "t", now).toISOString()).toBe(inHours(1));
  });

  it("odmietne minulosť, ďalekú budúcnosť aj nezmysel", () => {
    expect(code(() => requireFutureTime({ t: inHours(-2) }, "t", now))).toBe("invalid_t");
    expect(code(() => requireFutureTime({ t: inHours(24 * 400) }, "t", now))).toBe("invalid_t");
    expect(code(() => requireFutureTime({ t: "zajtra" }, "t", now))).toBe("invalid_t");
  });
});

describe("parsovanie komunity", () => {
  const future = new Date(Date.now() + 3600_000).toISOString();

  it("tréning s parťákom: miesto je povinné, poznámka nie", () => {
    const draft = parseBuddy({ startsAt: future, place: "  Fitko Nivy ", focus: "Nohy" });
    expect(draft).toMatchObject({ place: "Fitko Nivy", focus: "Nohy", note: null });
    expect(code(() => parseBuddy({ startsAt: future, place: "" }))).toBe("invalid_place");
  });

  it("udalosť má názov a miesto", () => {
    expect(parseEvent({ title: "Beh", place: "Draždiak", startsAt: future }).description).toBeNull();
    expect(code(() => parseEvent({ title: "x".repeat(81), place: "A", startsAt: future }))).toBe("invalid_title");
  });

  it("výzva potrebuje dátumy a cieľ 1 až 366", () => {
    const ok = { title: "30 dní", goalDays: 20, startsOn: "2026-11-16", endsOn: "2026-12-15" };
    expect(parseChallenge(ok).goalDays).toBe(20);
    expect(code(() => parseChallenge({ ...ok, goalDays: 0 }))).toBe("invalid_goalDays");
    expect(code(() => parseChallenge({ ...ok, startsOn: "2026-02-30" }))).toBe("invalid_startsOn");
  });
});

describe("checkChallengeDates", () => {
  const base = { title: "V", description: null, startsOn: "2026-11-16", endsOn: "2026-11-30", goalDays: 10 };

  it("prijme rozumnú výzvu", () => {
    expect(() => checkChallengeDates(base, "2026-11-16")).not.toThrow();
  });

  it("odmietne cieľ dlhší ako výzva, koniec pred začiatkom a skončenú výzvu", () => {
    expect(code(() => checkChallengeDates({ ...base, goalDays: 16 }, "2026-11-16"))).toBe("invalid_goalDays");
    expect(code(() => checkChallengeDates({ ...base, endsOn: "2026-11-10" }, "2026-11-01"))).toBe("invalid_dates");
    expect(code(() => checkChallengeDates(base, "2026-12-01"))).toBe("invalid_endsOn");
  });
});
