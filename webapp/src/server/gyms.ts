import type { Db, Tx } from "./db";
import { HttpError, pgCode } from "./errors";

/** Najviac fitiek v jednej odpovedi (celá zemeguľa naraz). */
export const MAX_GYMS_PER_LIST = 5000;

const gymNotFound = () => new HttpError(404, "gym_not_found", "Fitko sme nenašli.");

/** Spoločný SELECT: fitko, súhrn hodnotení a moje hodnotenie. */
const select = `
  SELECT g.id::text, g.name, g.address, g.city, g.lat, g.lng,
         g.opening_hours, g.tags, g.website, g.photo_urls,
         coalesce(r.s1, 0) AS s1, coalesce(r.s2, 0) AS s2, coalesce(r.s3, 0) AS s3,
         coalesce(r.s4, 0) AS s4, coalesce(r.s5, 0) AS s5,
         mine.stars AS my_stars
  FROM gyms g
  LEFT JOIN gym_rating_summary() r ON r.gym_id = g.id
  LEFT JOIN gym_reviews mine ON mine.gym_id = g.id AND mine.user_id = app_user_id()`;

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
  s1: number;
  s2: number;
  s3: number;
  s4: number;
  s5: number;
  my_stars: number | null;
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
