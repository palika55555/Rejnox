-- Rejnox: komunita – príspevky (lajky, komentáre), parťáci na tréning,
-- udalosti, výzvy a týždenný rebríček aktivity.
-- Čítať môže každý prihlásený, zapisovať a mazať len vlastné záznamy (RLS).
-- Mená ostatných appka berie z pohľadu public_profiles (002_security).
-- Rebríček: len ľudia s users.leaderboard_opt_in (zapína si to každý sám).

-- --------------------------------------------------------------- príspevky

CREATE TABLE IF NOT EXISTS community_posts (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS community_posts_created_idx ON community_posts (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS community_posts_author_idx ON community_posts (author_id);

CREATE TABLE IF NOT EXISTS community_post_likes (
  post_id    uuid NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS community_post_likes_user_idx ON community_post_likes (user_id);

CREATE TABLE IF NOT EXISTS community_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid NOT NULL REFERENCES community_posts (id) ON DELETE CASCADE,
  author_id  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS community_comments_post_idx ON community_comments (post_id, created_at);
CREATE INDEX IF NOT EXISTS community_comments_author_idx ON community_comments (author_id);

-- --------------------------------------------- parťáci (spoločné tréningy)
-- Tabuľky partner_sessions a partner_session_members sú z 001_init.

ALTER TABLE partner_sessions
  ADD COLUMN IF NOT EXISTS place text,
  ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE partner_sessions DROP CONSTRAINT IF EXISTS partner_sessions_text_len;
ALTER TABLE partner_sessions ADD CONSTRAINT partner_sessions_text_len CHECK (
  (place IS NULL OR char_length(place) BETWEEN 1 AND 120)
  AND (focus IS NULL OR char_length(focus) BETWEEN 1 AND 60)
  AND (note IS NULL OR char_length(note) BETWEEN 1 AND 300)
) NOT VALID;
CREATE INDEX IF NOT EXISTS partner_sessions_host_idx ON partner_sessions (host_id);
CREATE INDEX IF NOT EXISTS partner_session_members_user_idx ON partner_session_members (user_id);

-- ---------------------------------------------------------------- udalosti

CREATE TABLE IF NOT EXISTS community_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title       text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  place       text NOT NULL CHECK (char_length(place) BETWEEN 1 AND 120),
  description text CHECK (description IS NULL OR char_length(description) BETWEEN 1 AND 500),
  starts_at   timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS community_events_time_idx ON community_events (starts_at);
CREATE INDEX IF NOT EXISTS community_events_creator_idx ON community_events (created_by);

CREATE TABLE IF NOT EXISTS community_event_attendees (
  event_id  uuid NOT NULL REFERENCES community_events (id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS community_event_attendees_user_idx ON community_event_attendees (user_id);

-- ------------------------------------------------------------------ výzvy
-- Cieľ = počet dní s tréningom medzi starts_on a ends_on. Pokrok sa ráta
-- zo skutočných sérií (set_logs), nikto si ho nevie „dopísať“.

CREATE TABLE IF NOT EXISTS community_challenges (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by  uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title       text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  description text CHECK (description IS NULL OR char_length(description) BETWEEN 1 AND 500),
  goal_days   integer NOT NULL CHECK (goal_days BETWEEN 1 AND 366),
  starts_on   date NOT NULL,
  ends_on     date NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_on >= starts_on AND ends_on - starts_on <= 366 AND goal_days <= ends_on - starts_on + 1)
);
CREATE INDEX IF NOT EXISTS community_challenges_end_idx ON community_challenges (ends_on);
CREATE INDEX IF NOT EXISTS community_challenges_creator_idx ON community_challenges (created_by);

CREATE TABLE IF NOT EXISTS community_challenge_members (
  challenge_id uuid NOT NULL REFERENCES community_challenges (id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  joined_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, user_id)
);
CREATE INDEX IF NOT EXISTS community_challenge_members_user_idx ON community_challenge_members (user_id);

-- --------------------------------------------------------------- funkcie

-- Počet dní s tréningom človeka v rozsahu dátumov (pre výzvy a rebríček).
-- SECURITY DEFINER, lebo set_logs inak vidí len vlastník a jeho tréner;
-- vracia len číslo, nie samotné série.
CREATE OR REPLACE FUNCTION training_days_between(p_user uuid, p_from date, p_to date, p_zone text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT count(DISTINCT (s.performed_at AT TIME ZONE p_zone)::date)::int
  FROM set_logs s
  LEFT JOIN trainer_clients tc ON tc.id = s.trainer_client_id
  WHERE coalesce(s.user_id, tc.client_user_id) = p_user
    AND (s.performed_at AT TIME ZONE p_zone)::date BETWEEN p_from AND p_to
$$;

-- Pokrok vo výzve smie čítať len člen výzvy, a to pre seba alebo pre
-- ostatných členov tej istej výzvy.
CREATE OR REPLACE FUNCTION challenge_progress(p_challenge uuid, p_user uuid, p_zone text)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT training_days_between(p_user, c.starts_on, least(c.ends_on, (now() AT TIME ZONE p_zone)::date), p_zone)
  FROM community_challenges c
  WHERE c.id = p_challenge
    AND app_user_id() IS NOT NULL
    AND EXISTS (SELECT 1 FROM community_challenge_members m WHERE m.challenge_id = c.id AND m.user_id = p_user)
$$;

-- Týždenný rebríček: dni s tréningom za posledných 7 dní, len ľudia,
-- ktorí si rebríček zapli. Bez detailov o sériách.
CREATE OR REPLACE FUNCTION weekly_activity_leaderboard(p_zone text, p_limit integer)
RETURNS TABLE (user_id uuid, display_name text, city text, days integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  WITH today AS (SELECT (now() AT TIME ZONE p_zone)::date AS d)
  SELECT u.id, u.display_name, u.city,
         training_days_between(u.id, (SELECT d FROM today) - 6, (SELECT d FROM today), p_zone) AS days
  FROM users u
  WHERE u.leaderboard_opt_in AND app_user_id() IS NOT NULL
  ORDER BY days DESC, lower(u.display_name), u.id
  LIMIT least(greatest(p_limit, 1), 200)
$$;

-- Upozornenia pre autora: lajk, komentár, nový parťák, účastník udalosti.
CREATE OR REPLACE FUNCTION notify_community() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  who text := coalesce(display_name_of(NEW.user_id), 'Niekto');
BEGIN
  IF TG_TABLE_NAME = 'community_post_likes' THEN
    PERFORM notify((SELECT author_id FROM community_posts WHERE id = NEW.post_id),
                   'community', who || ' lajkol tvoj príspevok', NULL, NULL);
  ELSIF TG_TABLE_NAME = 'partner_session_members' THEN
    PERFORM notify((SELECT host_id FROM partner_sessions WHERE id = NEW.session_id),
                   'community', who || ' sa pridal k tvojmu tréningu', NULL, NULL);
  ELSIF TG_TABLE_NAME = 'community_event_attendees' THEN
    PERFORM notify((SELECT created_by FROM community_events WHERE id = NEW.event_id),
                   'community', who || ' príde na tvoju udalosť', NULL, NULL);
  END IF;
  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION notify_community_comment() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM notify((SELECT author_id FROM community_posts WHERE id = NEW.post_id),
                 'community', coalesce(display_name_of(NEW.author_id), 'Niekto') || ' komentoval tvoj príspevok',
                 NEW.body, NULL);
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS community_post_likes_notify ON community_post_likes;
CREATE TRIGGER community_post_likes_notify AFTER INSERT ON community_post_likes
  FOR EACH ROW EXECUTE FUNCTION notify_community();
DROP TRIGGER IF EXISTS partner_session_members_notify ON partner_session_members;
CREATE TRIGGER partner_session_members_notify AFTER INSERT ON partner_session_members
  FOR EACH ROW EXECUTE FUNCTION notify_community();
DROP TRIGGER IF EXISTS community_event_attendees_notify ON community_event_attendees;
CREATE TRIGGER community_event_attendees_notify AFTER INSERT ON community_event_attendees
  FOR EACH ROW EXECUTE FUNCTION notify_community();
DROP TRIGGER IF EXISTS community_comments_notify ON community_comments;
CREATE TRIGGER community_comments_notify AFTER INSERT ON community_comments
  FOR EACH ROW EXECUTE FUNCTION notify_community_comment();

-- ------------------------------------------------------------------ práva

REVOKE ALL ON FUNCTION training_days_between(uuid, date, date, text),
  challenge_progress(uuid, uuid, text), weekly_activity_leaderboard(text, integer),
  notify_community(), notify_community_comment() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION challenge_progress(uuid, uuid, text),
  weekly_activity_leaderboard(text, integer) TO rejnox_app;

GRANT SELECT, INSERT, DELETE ON community_posts, community_post_likes, community_comments,
  community_events, community_event_attendees, community_challenges, community_challenge_members
  TO rejnox_app;

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_posts_read ON community_posts FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_posts_insert ON community_posts FOR INSERT TO rejnox_app
  WITH CHECK (author_id = app_user_id());
CREATE POLICY community_posts_delete ON community_posts FOR DELETE TO rejnox_app
  USING (author_id = app_user_id());

ALTER TABLE community_post_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_post_likes_read ON community_post_likes FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_post_likes_insert ON community_post_likes FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id());
CREATE POLICY community_post_likes_delete ON community_post_likes FOR DELETE TO rejnox_app
  USING (user_id = app_user_id());

ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_comments_read ON community_comments FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_comments_insert ON community_comments FOR INSERT TO rejnox_app
  WITH CHECK (author_id = app_user_id());
-- Komentár zmaže jeho autor alebo autor príspevku.
CREATE POLICY community_comments_delete ON community_comments FOR DELETE TO rejnox_app
  USING (author_id = app_user_id()
         OR EXISTS (SELECT 1 FROM community_posts p WHERE p.id = post_id AND p.author_id = app_user_id()));

ALTER TABLE community_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_events_read ON community_events FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_events_insert ON community_events FOR INSERT TO rejnox_app
  WITH CHECK (created_by = app_user_id());
CREATE POLICY community_events_delete ON community_events FOR DELETE TO rejnox_app
  USING (created_by = app_user_id());

ALTER TABLE community_event_attendees ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_event_attendees_read ON community_event_attendees FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_event_attendees_join ON community_event_attendees FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id());
CREATE POLICY community_event_attendees_leave ON community_event_attendees FOR DELETE TO rejnox_app
  USING (user_id = app_user_id());

ALTER TABLE community_challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_challenges_read ON community_challenges FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_challenges_insert ON community_challenges FOR INSERT TO rejnox_app
  WITH CHECK (created_by = app_user_id());
CREATE POLICY community_challenges_delete ON community_challenges FOR DELETE TO rejnox_app
  USING (created_by = app_user_id());

ALTER TABLE community_challenge_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY community_challenge_members_read ON community_challenge_members FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY community_challenge_members_join ON community_challenge_members FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id());
CREATE POLICY community_challenge_members_leave ON community_challenge_members FOR DELETE TO rejnox_app
  USING (user_id = app_user_id());
