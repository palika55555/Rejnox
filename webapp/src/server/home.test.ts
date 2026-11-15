import { describe, expect, it } from "vitest";
import { monthDelta, streakDays, weekDays } from "./home";

describe("séria dní", () => {
  it("bez tréningov je nula", () => {
    expect(streakDays([], "2026-11-15")).toBe(0);
  });

  it("počíta dni za sebou končiace dnes", () => {
    expect(streakDays(["2026-11-15", "2026-11-14", "2026-11-13", "2026-11-11"], "2026-11-15")).toBe(3);
  });

  it("dnes ešte necvičil: séria zo včerajška platí", () => {
    expect(streakDays(["2026-11-14", "2026-11-13"], "2026-11-15")).toBe(2);
  });

  it("posledný tréning predvčerom sériu preruší", () => {
    expect(streakDays(["2026-11-13", "2026-11-12"], "2026-11-15")).toBe(0);
  });

  it("cez prelom mesiaca", () => {
    expect(streakDays(["2026-12-01", "2026-11-30"], "2026-12-01")).toBe(2);
  });
});

describe("dni tréningu v tomto týždni", () => {
  it("týždeň začína pondelkom", () => {
    // 2026-11-15 je nedeľa, pondelok je 2026-11-09.
    expect(weekDays(["2026-11-15", "2026-11-09", "2026-11-08"], "2026-11-15")).toBe(2);
  });

  it("v pondelok sa ráta len pondelok", () => {
    expect(weekDays(["2026-11-16", "2026-11-15"], "2026-11-16")).toBe(1);
  });
});

describe("zlepšenie za mesiac", () => {
  it("rozdiel oproti najlepšiemu výkonu spred mesiaca", () => {
    expect(monthDelta(140, 135, [137.5, 140])).toBe(5);
  });

  it("bez starších sérií: rozdiel oproti prvému dňu v mesiaci", () => {
    expect(monthDelta(100, null, [90, 95, 100])).toBe(10);
  });

  it("jediný deň znamená nulu", () => {
    expect(monthDelta(60, null, [60])).toBe(0);
  });
});
