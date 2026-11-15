import type { Db, Tx } from "./db";
import { HttpError, pgCode } from "./errors";
import { optionalText, requireText, type Body } from "./validate";

/** Najviac fitiek v jednej odpovedi (celá zemeguľa naraz). */
export const MAX_GYMS_PER_LIST = 5000;
/** Najviac nahratých fotiek pri jednom fitku. */
export const MAX_PHOTOS_PER_GYM = 20;
/** Najviac položiek cenníka pri jednom fitku. */
export const MAX_PRICES_PER_GYM = 40;
/** Fotka po zmenšení v appke má pár stoviek kB, toto je strop. */
export const MAX_PHOTO_BYTES = 1_500_000;

const MAX_TAGS = 12;
const MAX_PRICE_CENTS = 10_000_000;

const gymNotFound = () => new HttpError(404, "gym_not_found", "Fitko sme nenašli.");
const photoNotFound = () => new HttpError(404, "photo_not_found", "Fotku sme nenašli.");
const priceNotFound = () => new HttpError(404, "price_not_found", "Cenu sme nenašli.");
const notMine = () => new HttpError(403, "not_owner", "Toto môže zmeniť len ten, kto to pridal.");

/** Spoločný SELECT: fitko, súhrn hodnotení, moje hodnotenie, fotky a cenník. */
const select = `
  SELECT g.id::text, g.name, g.address, g.city, g.lat, g.lng,
         g.opening_hours, g.tags, g.website, g.photo_urls,
         coalesce(g.created_by = app_user_id(), false) AS mine,
         coalesce(r.s1, 0) AS s1, coalesce(r.s2, 0) AS s2, coalesce(r.s3, 0) AS s3,
         coalesce(r.s4, 0) AS s4, coalesce(r.s5, 0) AS s5,
         mine.stars AS my_stars,
         coalesce(ph.photos, '[]') AS photos,
         coalesce(pr.prices, '[]') AS prices
  FROM gyms g
  LEFT JOIN gym_rating_summary() r ON r.gym_id = g.id
  LEFT JOIN gym_reviews mine ON mine.gym_id = g.id AND mine.user_id = app_user_id()
  LEFT JOIN LATERAL (
    SELECT json_agg(json_build_object(
             'id', p.id::text,
             'mine', coalesce(p.uploaded_by = app_user_id(), false))
           ORDER BY p.created_at, p.id) AS photos
    FROM gym_photos p WHERE p.gym_id = g.id
  ) ph ON true
  LEFT JOIN LATERAL (
    SELECT json_agg(json_build_object(
             'id', c.id::text,
             'kind', c.kind,
             'title', c.title,
             'priceCents', c.price_cents,
             'currency', c.currency,
             'period', c.period,
             'mine', coalesce(c.submitted_by = app_user_id(), false))
           ORDER BY c.kind, c.price_cents, c.id) AS prices
    FROM gym_prices c WHERE c.gym_id = g.id
  ) pr ON true`;

type GymRow = {
  id: string;
  name: string;
  address: string | null;
  city: string | null;
  lat: number;
  lng: number;
  opening_hours: string | null;
  tags: string[] | null;
  website: string | null;
  photo_urls: string[] | null;
  mine: boolean;
  s1: number;
  s2: number;
  s3: number;
  s4: number;
  s5: number;
  my_stars: number | null;
  photos: { id: string; mine: boolean }[];
  prices: Record<string, unknown>[];
};

const gymJson = (r: GymRow) => ({
  id: r.id,
  name: r.name,
  address: r.address,
  city: r.city ?? "",
  lat: r.lat,
  lng: r.lng,
  openingHours: r.opening_hours,
  tags: r.tags ?? [],
  website: r.website,
  photoUrls: r.photo_urls ?? [],
  photos: r.photos,
  prices: r.prices,
  mine: r.mine,
  rating: { stars: [r.s1, r.s2, r.s3, r.s4, r.s5] },
  myStars: r.my_stars,
});

async function one(tx: Tx, gymId: string) {
  const [row] = await tx.query<GymRow>(`${select} WHERE g.id = $1::uuid`, [gymId]);
  if (!row) throw gymNotFound();
  return gymJson(row);
}

/** Všetky fitká sveta zoradené podľa názvu. */
export function listGyms(db: Db, userId: string) {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query<GymRow>(`${select} ORDER BY g.name LIMIT $1`, [MAX_GYMS_PER_LIST]);
    return rows.map(gymJson);
  });
}

export function gymDetail(db: Db, userId: string, gymId: string) {
  return db.asUser(userId, (tx) => one(tx, gymId));
}

// ------------------------------------------------------------ nové fitko

/** Fitko tak, ako ho zadal používateľ v appke. */
export type GymInput = {
  name: string;
  address: string | null;
  city: string;
  lat: number;
  lng: number;
  openingHours: string | null;
  tags: string[];
  website: string | null;
};

function coordinate(value: unknown, field: "lat" | "lng", limit: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || Math.abs(value) > limit) {
    throw new HttpError(400, `invalid_${field}`, "Vyber polohu fitka na mape.");
  }
  return value;
}

function parseTags(value: unknown): string[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > MAX_TAGS) {
    throw new HttpError(400, "invalid_tags", `Najviac ${MAX_TAGS} zameraní.`);
  }
  const tags: string[] = [];
  for (const raw of value) {
    const tag = typeof raw === "string" ? raw.trim() : "";
    if (tag.length === 0 || tag.length > 40) {
      throw new HttpError(400, "invalid_tags", "Zameranie musí mať 1 až 40 znakov.");
    }
    if (!tags.includes(tag)) tags.push(tag);
  }
  return tags;
}

function parseWebsite(body: Body): string | null {
  const text = optionalText(body, "website", 300);
  if (text === null) return null;
  const withScheme = /^[a-z][a-z0-9+.-]*:/i.test(text) ? text : `https://${text}`;
  let url: URL;
  try {
    url = new URL(withScheme);
  } catch {
    throw new HttpError(400, "invalid_website", "Web musí byť platná adresa (https://…).");
  }
  if (url.protocol !== "https:" || !url.hostname.includes(".") || /\s/.test(withScheme)) {
    throw new HttpError(400, "invalid_website", "Web musí byť platná adresa (https://…).");
  }
  return url.toString();
}

/** Rozparsuje a overí fitko z tela požiadavky. */
export function parseGymInput(body: Body): GymInput {
  return {
    name: requireText(body, "name", 120, "Názov"),
    address: optionalText(body, "address", 200),
    city: requireText(body, "city", 80, "Mesto"),
    lat: coordinate(body.lat, "lat", 90),
    lng: coordinate(body.lng, "lng", 180),
    openingHours: optionalText(body, "openingHours", 120),
    tags: parseTags(body.tags),
    website: parseWebsite(body),
  };
}

const gymParams = (g: GymInput) => [g.name, g.address, g.city, g.lat, g.lng, g.openingHours, g.tags, g.website];

/** Pridá nové fitko (autor je prihlásený používateľ). */
export function createGym(db: Db, userId: string, input: GymInput) {
  return db.asUser(userId, async (tx) => {
    const [row] = await tx.query<{ id: string }>(
      `INSERT INTO gyms (name, address, city, lat, lng, opening_hours, tags, website, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::uuid) RETURNING id::text`,
      [...gymParams(input), userId],
    );
    return one(tx, row.id);
  });
}

/** Zistí, či fitko existuje (pre rozlíšenie 404 a 403 po RLS). */
async function requireGym(tx: Tx, gymId: string): Promise<void> {
  const [row] = await tx.query("SELECT 1 FROM gyms WHERE id = $1::uuid", [gymId]);
  if (!row) throw gymNotFound();
}

/** Zmení fitko. Môže len ten, kto ho pridal (RLS gyms_update). */
export function updateGym(db: Db, userId: string, gymId: string, input: GymInput) {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query(
      `UPDATE gyms SET name = $1, address = $2, city = $3, lat = $4, lng = $5,
              opening_hours = $6, tags = $7, website = $8
       WHERE id = $9::uuid RETURNING id`,
      [...gymParams(input), gymId],
    );
    if (rows.length === 0) {
      await requireGym(tx, gymId);
      throw notMine();
    }
    return one(tx, gymId);
  });
}

/** Zmaže fitko aj s fotkami, cenníkom a hodnoteniami. Len autor. */
export function deleteGym(db: Db, userId: string, gymId: string) {
  return db.asUser(userId, async (tx) => {
    const rows = await tx.query("DELETE FROM gyms WHERE id = $1::uuid RETURNING id", [gymId]);
    if (rows.length === 0) {
      await requireGym(tx, gymId);
      throw notMine();
    }
  });
}

// ------------------------------------------------------------ hodnotenie

/** Uloží (alebo zmení) moje hodnotenie a vráti aktualizované fitko. */
export function rateGym(db: Db, userId: string, gymId: string, stars: number) {
  return db.asUser(userId, async (tx) => {
    try {
      await tx.query(
        `INSERT INTO gym_reviews (gym_id, user_id, stars)
         VALUES ($1::uuid, $2::uuid, $3)
         ON CONFLICT (gym_id, user_id) DO UPDATE SET stars = EXCLUDED.stars, updated_at = now()`,
        [gymId, userId, stars],
      );
    } catch (error) {
      if (pgCode(error) === "23503") throw gymNotFound(); // fitko neexistuje
      throw error;
    }
    return one(tx, gymId);
  });
}

/** Zmaže moje hodnotenie a vráti aktualizované fitko. */
export function unrateGym(db: Db, userId: string, gymId: string) {
  return db.asUser(userId, async (tx) => {
    await tx.query("DELETE FROM gym_reviews WHERE gym_id = $1::uuid AND user_id = $2::uuid", [gymId, userId]);
    return one(tx, gymId);
  });
}

// ------------------------------------------------------------ fotky

const startsWith = (bytes: Uint8Array, prefix: number[], offset = 0) =>
  bytes.length >= offset + prefix.length && prefix.every((b, i) => bytes[offset + i] === b);

/**
 * Typ obrázka podľa prvých bajtov (hlavičke Content-Type neveríme).
 * Iné formáty (HEIC, GIF, SVG…) server neprijme.
 */
export function sniffImageType(bytes: Uint8Array): "image/jpeg" | "image/png" | "image/webp" | null {
  if (startsWith(bytes, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return "image/png";
  if (startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) && startsWith(bytes, [0x57, 0x45, 0x42, 0x50], 8)) {
    return "image/webp";
  }
  return null;
}

/** Nahrá fotku k fitku a vráti aktualizované fitko. */
export function addPhoto(db: Db, userId: string, gymId: string, bytes: Uint8Array) {
  const contentType = sniffImageType(bytes);
  if (!contentType) {
    throw new HttpError(415, "invalid_image", "Fotka musí byť JPEG, PNG alebo WebP.");
  }
  return db.asUser(userId, async (tx) => {
    await requireGym(tx, gymId);
    const [{ n }] = await tx.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM gym_photos WHERE gym_id = $1::uuid",
      [gymId],
    );
    if (n >= MAX_PHOTOS_PER_GYM) {
      throw new HttpError(409, "too_many_photos", `Fitko už má ${MAX_PHOTOS_PER_GYM} fotiek.`);
    }
    await tx.query(
      `INSERT INTO gym_photos (gym_id, uploaded_by, content_type, data)
       VALUES ($1::uuid, $2::uuid, $3, $4)`,
      [gymId, userId, contentType, Buffer.from(bytes)],
    );
    return one(tx, gymId);
  });
}

/** Obsah fotky (bajty a typ). */
export function photo(db: Db, userId: string, photoId: string) {
  return db.asUser(userId, async (tx) => {
    const [row] = await tx.query<{ content_type: string; data: Uint8Array }>(
      "SELECT content_type, data FROM gym_photos WHERE id = $1::uuid",
      [photoId],
    );
    if (!row) throw photoNotFound();
    return { contentType: row.content_type, bytes: row.data };
  });
}

/** Zmaže moju fotku a vráti aktualizované fitko. */
export function deletePhoto(db: Db, userId: string, photoId: string) {
  return db.asUser(userId, async (tx) => {
    const [deleted] = await tx.query<{ gym_id: string }>(
      "DELETE FROM gym_photos WHERE id = $1::uuid RETURNING gym_id::text",
      [photoId],
    );
    if (!deleted) {
      const [exists] = await tx.query("SELECT 1 FROM gym_photos WHERE id = $1::uuid", [photoId]);
      throw exists ? notMine() : photoNotFound();
    }
    return one(tx, deleted.gym_id);
  });
}

// ------------------------------------------------------------ cenník

export const priceKinds = ["membership", "product"] as const;

/** Položka cenníka: permanentka (aj jednorazový vstup) alebo produkt. */
export type PriceInput = {
  kind: (typeof priceKinds)[number];
  title: string;
  priceCents: number;
  period: string | null;
};

export function parsePriceInput(body: Body): PriceInput {
  const kind = body.kind;
  if (typeof kind !== "string" || !(priceKinds as readonly string[]).includes(kind)) {
    throw new HttpError(400, "invalid_kind", "Neplatný druh ceny.");
  }
  const cents = body.priceCents;
  if (typeof cents !== "number" || !Number.isInteger(cents) || cents < 0 || cents > MAX_PRICE_CENTS) {
    throw new HttpError(400, "invalid_priceCents", "Zadaj cenu 0 až 100 000 €.");
  }
  return {
    kind: kind as PriceInput["kind"],
    title: requireText(body, "title", 120, "Názov"),
    priceCents: cents,
    period: optionalText(body, "period", 40),
  };
}

/** Pridá položku do cenníka fitka a vráti aktualizované fitko. */
export function addPrice(db: Db, userId: string, gymId: string, input: PriceInput) {
  return db.asUser(userId, async (tx) => {
    await requireGym(tx, gymId);
    const [{ n }] = await tx.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM gym_prices WHERE gym_id = $1::uuid",
      [gymId],
    );
    if (n >= MAX_PRICES_PER_GYM) {
      throw new HttpError(409, "too_many_prices", `Cenník už má ${MAX_PRICES_PER_GYM} položiek.`);
    }
    await tx.query(
      `INSERT INTO gym_prices (gym_id, kind, title, price_cents, period, submitted_by)
       VALUES ($1::uuid, $2, $3, $4, $5, $6::uuid)`,
      [gymId, input.kind, input.title, input.priceCents, input.period, userId],
    );
    return one(tx, gymId);
  });
}

/** Zmaže moju položku cenníka a vráti aktualizované fitko. */
export function deletePrice(db: Db, userId: string, priceId: string) {
  return db.asUser(userId, async (tx) => {
    const [deleted] = await tx.query<{ gym_id: string }>(
      "DELETE FROM gym_prices WHERE id = $1::uuid RETURNING gym_id::text",
      [priceId],
    );
    if (!deleted) {
      const [exists] = await tx.query("SELECT 1 FROM gym_prices WHERE id = $1::uuid", [priceId]);
      throw exists ? notMine() : priceNotFound();
    }
    return one(tx, deleted.gym_id);
  });
}
