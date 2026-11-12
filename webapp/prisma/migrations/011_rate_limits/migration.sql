-- Rejnox: limity pokusov (prihlásenie, registrácia, pozývacie kódy).
-- Na Cloudflare Workers beží viac inštancií naraz, preto počítadlo musí byť
-- v databáze, nie v pamäti servera. Kľúč je SHA-256 odtlačok (napr. IP|e-mail),
-- takže sa tu neukladajú e-maily ani IP adresy.

CREATE TABLE rate_limits (
  key      text PRIMARY KEY,
  hits     integer NOT NULL,
  reset_at timestamptz NOT NULL
);
-- Aplikácia k tabuľke nemá priamy prístup, len cez funkcie nižšie.
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

-- Zaráta pokus. Vráti false, ak je limit pre kľúč v aktuálnom okne vyčerpaný.
CREATE FUNCTION rate_limit_hit(p_key text, p_max integer, p_window_seconds integer)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  n integer;
BEGIN
  INSERT INTO rate_limits AS r (key, hits, reset_at)
  VALUES (p_key, 1, now() + make_interval(secs => p_window_seconds))
  ON CONFLICT (key) DO UPDATE SET
    hits = CASE WHEN r.reset_at <= now() THEN 1 ELSE r.hits + 1 END,
    reset_at = CASE WHEN r.reset_at <= now()
                    THEN now() + make_interval(secs => p_window_seconds)
                    ELSE r.reset_at END
  RETURNING hits INTO n;

  -- Občas upratať staré záznamy.
  IF random() < 0.01 THEN
    DELETE FROM rate_limits WHERE reset_at < now();
  END IF;
  RETURN n <= p_max;
END
$$;

-- Po úspechu (napr. správne heslo) limit vynuluje.
CREATE FUNCTION rate_limit_reset(p_key text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$ DELETE FROM rate_limits WHERE key = p_key $$;

REVOKE ALL ON FUNCTION rate_limit_hit(text, integer, integer), rate_limit_reset(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rate_limit_hit(text, integer, integer), rate_limit_reset(text) TO rejnox_app;
