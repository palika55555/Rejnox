-- Rejnox: detail fitka (hodiny, zameranie, web, fotky) a hodnotenia.
-- Hodnotenie je súkromné: každý vidí a mení len svoje. Ostatní vidia
-- len súhrn (počty hviezdičiek), nie kto ako hodnotil.

ALTER TABLE gyms
  ADD COLUMN opening_hours text
    CHECK (char_length(opening_hours) BETWEEN 1 AND 120),
  ADD COLUMN tags text[] NOT NULL DEFAULT '{}'
    CHECK (cardinality(tags) <= 12),
  ADD COLUMN website text
    CHECK (website ~ '^https://[^\s]{3,300}$'),
  ADD COLUMN photo_urls text[] NOT NULL DEFAULT '{}'
    CHECK (cardinality(photo_urls) <= 20);

CREATE TABLE gym_reviews (
  gym_id     uuid NOT NULL REFERENCES gyms (id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  stars      smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (gym_id, user_id)
);
CREATE INDEX gym_reviews_user_idx ON gym_reviews (user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON gym_reviews TO rejnox_app;

ALTER TABLE gym_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY gym_reviews_own ON gym_reviews TO rejnox_app
  USING (user_id = app_user_id()) WITH CHECK (user_id = app_user_id());

-- Súhrn hodnotení všetkých fitiek: počty 1 až 5 hviezdičiek.
-- SECURITY DEFINER, lebo RLS by inak pustilo len vlastné hodnotenia.
CREATE FUNCTION gym_rating_summary()
RETURNS TABLE (gym_id uuid, s1 int, s2 int, s3 int, s4 int, s5 int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT r.gym_id,
         count(*) FILTER (WHERE r.stars = 1)::int,
         count(*) FILTER (WHERE r.stars = 2)::int,
         count(*) FILTER (WHERE r.stars = 3)::int,
         count(*) FILTER (WHERE r.stars = 4)::int,
         count(*) FILTER (WHERE r.stars = 5)::int
  FROM gym_reviews r
  WHERE app_user_id() IS NOT NULL
  GROUP BY r.gym_id
$$;

REVOKE ALL ON FUNCTION gym_rating_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gym_rating_summary() TO rejnox_app;
