import { describe, expect, it } from "vitest";
import { HttpError } from "./errors";
import { parseGymInput, parsePriceInput, sniffImageType } from "./gyms";

function code(fn: () => unknown): string {
  try {
    fn();
    return "ok";
  } catch (error) {
    if (error instanceof HttpError) return error.code;
    throw error;
  }
}

const valid = { name: " Gym Nitra ", city: "Nitra", lat: 48.3, lng: 18.08 };

describe("parseGymInput", () => {
  it("prijme minimálne fitko a doplní prázdne polia", () => {
    expect(parseGymInput(valid)).toEqual({
      name: "Gym Nitra",
      address: null,
      city: "Nitra",
      lat: 48.3,
      lng: 18.08,
      openingHours: null,
      tags: [],
      website: null,
    });
  });

  it("web doplní o https a odmietne iné schémy", () => {
    expect(parseGymInput({ ...valid, website: "gymnitra.sk" }).website).toBe("https://gymnitra.sk/");
    expect(code(() => parseGymInput({ ...valid, website: "http://gymnitra.sk" }))).toBe("invalid_website");
    expect(code(() => parseGymInput({ ...valid, website: "javascript:alert(1)" }))).toBe("invalid_website");
    expect(code(() => parseGymInput({ ...valid, website: "localhost" }))).toBe("invalid_website");
  });

  it("zameranie: orezané, bez duplicít, s limitom", () => {
    expect(parseGymInput({ ...valid, tags: [" Kardio", "Kardio", "Sauna"] }).tags).toEqual(["Kardio", "Sauna"]);
    expect(code(() => parseGymInput({ ...valid, tags: ["x".repeat(41)] }))).toBe("invalid_tags");
    expect(code(() => parseGymInput({ ...valid, tags: Array.from({ length: 13 }, (_, i) => `t${i}`) }))).toBe(
      "invalid_tags",
    );
    expect(code(() => parseGymInput({ ...valid, tags: "Kardio" }))).toBe("invalid_tags");
  });

  it("odmietne chýbajúci názov, mesto a polohu mimo Zeme", () => {
    expect(code(() => parseGymInput({ ...valid, name: "  " }))).toBe("invalid_name");
    expect(code(() => parseGymInput({ ...valid, city: undefined }))).toBe("invalid_city");
    expect(code(() => parseGymInput({ ...valid, lat: 91 }))).toBe("invalid_lat");
    expect(code(() => parseGymInput({ ...valid, lng: "18" }))).toBe("invalid_lng");
    expect(code(() => parseGymInput({ ...valid, lng: Number.NaN }))).toBe("invalid_lng");
  });
});

describe("parsePriceInput", () => {
  it("prijme permanentku s obdobím", () => {
    expect(parsePriceInput({ kind: "membership", title: "Mesačná", priceCents: 3900, period: "mesiac" })).toEqual({
      kind: "membership",
      title: "Mesačná",
      priceCents: 3900,
      period: "mesiac",
    });
  });

  it("odmietne neznámy druh a zlú cenu", () => {
    expect(code(() => parsePriceInput({ kind: "gift", title: "x", priceCents: 1 }))).toBe("invalid_kind");
    expect(code(() => parsePriceInput({ kind: "product", title: "x", priceCents: 1.5 }))).toBe("invalid_priceCents");
    expect(code(() => parsePriceInput({ kind: "product", title: "x", priceCents: -1 }))).toBe("invalid_priceCents");
    expect(code(() => parsePriceInput({ kind: "product", title: "", priceCents: 1 }))).toBe("invalid_title");
  });
});

describe("sniffImageType", () => {
  const bytes = (...b: number[]) => new Uint8Array(b);

  it("rozozná JPEG, PNG a WebP podľa obsahu", () => {
    expect(sniffImageType(bytes(0xff, 0xd8, 0xff, 0xe0))).toBe("image/jpeg");
    expect(sniffImageType(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0))).toBe("image/png");
    const webp = new TextEncoder().encode("RIFF\0\0\0\0WEBPVP8 ");
    expect(sniffImageType(webp)).toBe("image/webp");
  });

  it("ostatné odmietne", () => {
    expect(sniffImageType(new TextEncoder().encode("<svg xmlns="))).toBeNull();
    expect(sniffImageType(new TextEncoder().encode("GIF89a"))).toBeNull();
    expect(sniffImageType(bytes())).toBeNull();
  });
});
