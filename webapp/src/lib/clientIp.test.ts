import { describe, expect, it } from "vitest";
import { clientIpFrom, proxyHops } from "./clientIp";

describe("clientIpFrom", () => {
  it("za jednou proxy vezme adresu, ktorú pripísala ona (sprava)", () => {
    // Návštevník podvrhol 1.2.3.4, proxy pripísala jeho skutočnú adresu.
    expect(clientIpFrom("1.2.3.4, 203.0.113.9", 1)).toBe("203.0.113.9");
  });

  it("za dvoma proxy vezme druhú adresu sprava", () => {
    expect(clientIpFrom("1.2.3.4, 203.0.113.9, 10.0.0.2", 2)).toBe("203.0.113.9");
  });

  it("bez hlavičky alebo s prázdnou hlavičkou nevráti nič", () => {
    expect(clientIpFrom(null, 1)).toBeUndefined();
    expect(clientIpFrom(" , ", 1)).toBeUndefined();
  });

  it("keď je adries menej ako proxy, hlavičke neverí", () => {
    expect(clientIpFrom("203.0.113.9", 2)).toBeUndefined();
  });

  it("pri 0 proxy hlavičku ignoruje", () => {
    expect(clientIpFrom("203.0.113.9", 0)).toBeUndefined();
  });
});

describe("proxyHops", () => {
  it("predvolene počíta s jednou proxy a odmietne nezmysly", () => {
    expect(proxyHops(undefined)).toBe(1);
    expect(proxyHops("2")).toBe(2);
    expect(proxyHops("0")).toBe(0);
    expect(proxyHops("-1")).toBe(1);
    expect(proxyHops("abc")).toBe(1);
  });
});
