import { describe, expect, it } from "vitest";
import { localDay, localTime, localToDate, mondayOf, weekStart } from "./zone";

describe("bratislavský čas", () => {
  it("zimný čas je UTC+1, letný UTC+2", () => {
    expect(localToDate("2026-11-16", "18:30")?.toISOString()).toBe("2026-11-16T17:30:00.000Z");
    expect(localToDate("2026-07-01", "08:00")?.toISOString()).toBe("2026-07-01T06:00:00.000Z");
  });

  it("deň zmeny času (29. 3. 2026) prepočíta správne", () => {
    expect(localToDate("2026-03-29", "01:00")?.toISOString()).toBe("2026-03-29T00:00:00.000Z");
    expect(localToDate("2026-03-29", "10:00")?.toISOString()).toBe("2026-03-29T08:00:00.000Z");
  });

  it("zlé vstupy vrátia null", () => {
    expect(localToDate("2026-02-30", "10:00")).toBeNull();
    expect(localToDate("2026-11-16", "24:00")).toBeNull();
    expect(localToDate("dnes", "10:00")).toBeNull();
  });

  it("okamih späť na deň a čas v Bratislave", () => {
    const instant = new Date("2026-11-16T23:30:00Z");
    expect(localDay(instant)).toBe("2026-11-17");
    expect(localTime(instant)).toBe("00:30");
  });

  it("týždeň začína pondelkom, zlý parameter = tento týždeň", () => {
    expect(mondayOf("2026-11-22")).toBe("2026-11-16");
    expect(weekStart("2026-11-19")).toBe("2026-11-16");
    expect(weekStart("x", new Date("2026-11-18T10:00:00Z"))).toBe("2026-11-16");
  });
});
