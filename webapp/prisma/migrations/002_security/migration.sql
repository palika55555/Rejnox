-- Rejnox: prístupové práva a Row Level Security pre rolu rejnox_app.

-- Prihlásený používateľ (nastavuje server cez SET LOCAL app.user_id).
CREATE FUNCTION app_user_id() RETURNS uuid
LANGUAGE sql STABLE
AS $$ SELECT nullif(current_setting('app.user_id', true), '')::uuid $$;

-- Má prihlásený prístup k údajom tohto klienta?
-- Tréner áno, kým spolupráca neskončila. Klient k svojim údajom vždy.
CREATE FUNCTION can_access_client(tc_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trainer_clients t
    WHERE t.id = tc_id
      AND ((t.trainer_id = app_user_id() AND t.status <> 'ended')
        OR t.client_user_id = app_user_id())
  )
$$;

CREATE FUNCTION is_conversation_member(conv_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM conversation_members m
    WHERE m.conversation_id = conv_id AND m.user_id = app_user_id()
  )
$$;

-- Prihlásenie: server potrebuje nájsť účet podľa e-mailu skôr, než vie, kto to je.
CREATE FUNCTION auth_find_user(p_email citext)
RETURNS TABLE (id uuid, password_hash text, role user_role)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$ SELECT u.id, u.password_hash, u.role FROM users u WHERE u.email = p_email $$;

-- Začne (alebo nájde) súkromnú konverzáciu s iným používateľom.
-- Členov konverzácie nejde pridávať priamo, aby sa nikto nevedel "pripojiť" do cudzej.
CREATE FUNCTION start_conversation(other_user uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  conv uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF other_user = me OR NOT EXISTS (SELECT 1 FROM users WHERE id = other_user) THEN
    RAISE EXCEPTION 'invalid recipient';
  END IF;

  SELECT a.conversation_id INTO conv
  FROM conversation_members a
  JOIN conversation_members b USING (conversation_id)
  WHERE a.user_id = me AND b.user_id = other_user
  LIMIT 1;

  IF conv IS NULL THEN
    INSERT INTO conversations DEFAULT VALUES RETURNING id INTO conv;
    INSERT INTO conversation_members (conversation_id, user_id)
    VALUES (conv, me), (conv, other_user);
  END IF;
  RETURN conv;
END
$$;

-- Verejná časť profilu (meno, rola, mesto). Nič citlivé.
CREATE VIEW public_profiles AS
SELECT id, display_name, role, city FROM users;

-- Rebríček osobných rekordov: len ľudia, ktorí si ho zapli.
CREATE VIEW leaderboard AS
SELECT e.id AS exercise_id,
       e.name AS exercise,
       u.id AS user_id,
       u.display_name,
       u.city,
       max(s.weight_kg) AS best_kg
FROM set_logs s
LEFT JOIN trainer_clients tc ON tc.id = s.trainer_client_id
JOIN users u ON u.id = coalesce(s.user_id, tc.client_user_id)
JOIN exercises e ON e.id = s.exercise_id
WHERE u.leaderboard_opt_in
GROUP BY e.id, e.name, u.id, u.display_name, u.city;

-- ------------------------------------------------------------------ práva

REVOKE ALL ON FUNCTION can_access_client(uuid), is_conversation_member(uuid),
  auth_find_user(citext), start_conversation(uuid) FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO rejnox_app;
GRANT EXECUTE ON FUNCTION app_user_id(), can_access_client(uuid),
  is_conversation_member(uuid), auth_find_user(citext), start_conversation(uuid)
  TO rejnox_app;

GRANT SELECT ON public_profiles, leaderboard TO rejnox_app;
GRANT SELECT, INSERT, UPDATE ON users TO rejnox_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON
  trainer_clients, gyms, gym_prices, exercises, workouts, workout_exercises,
  set_logs, bookings, partner_sessions, partner_session_members, member_passes
  TO rejnox_app;
GRANT SELECT ON conversations, conversation_members TO rejnox_app;
GRANT SELECT, INSERT ON messages TO rejnox_app;

-- ---------------------------------------------------- Row Level Security

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_self_select ON users FOR SELECT TO rejnox_app
  USING (id = app_user_id());
CREATE POLICY users_self_update ON users FOR UPDATE TO rejnox_app
  USING (id = app_user_id()) WITH CHECK (id = app_user_id());
-- Registrácia: nový účet môže vzniknúť bez prihlásenia.
CREATE POLICY users_register ON users FOR INSERT TO rejnox_app
  WITH CHECK (true);

ALTER TABLE trainer_clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY tc_select ON trainer_clients FOR SELECT TO rejnox_app
  USING (trainer_id = app_user_id() OR client_user_id = app_user_id());
CREATE POLICY tc_insert ON trainer_clients FOR INSERT TO rejnox_app
  WITH CHECK (trainer_id = app_user_id());
-- Upraviť môže tréner aj klient (klient tým vie spoluprácu ukončiť).
CREATE POLICY tc_update ON trainer_clients FOR UPDATE TO rejnox_app
  USING (trainer_id = app_user_id() OR client_user_id = app_user_id())
  WITH CHECK (trainer_id = app_user_id() OR client_user_id = app_user_id());
CREATE POLICY tc_delete ON trainer_clients FOR DELETE TO rejnox_app
  USING (trainer_id = app_user_id());

ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY workouts_access ON workouts TO rejnox_app
  USING (user_id = app_user_id() OR can_access_client(trainer_client_id))
  WITH CHECK (user_id = app_user_id() OR can_access_client(trainer_client_id));

ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY workout_exercises_access ON workout_exercises TO rejnox_app
  USING (EXISTS (SELECT 1 FROM workouts w WHERE w.id = workout_id))
  WITH CHECK (EXISTS (SELECT 1 FROM workouts w WHERE w.id = workout_id));

ALTER TABLE set_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY set_logs_access ON set_logs TO rejnox_app
  USING (user_id = app_user_id() OR can_access_client(trainer_client_id))
  WITH CHECK (user_id = app_user_id() OR can_access_client(trainer_client_id));

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY conversations_member ON conversations FOR SELECT TO rejnox_app
  USING (is_conversation_member(id));

ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY conversation_members_member ON conversation_members FOR SELECT TO rejnox_app
  USING (is_conversation_member(conversation_id));

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY messages_read ON messages FOR SELECT TO rejnox_app
  USING (is_conversation_member(conversation_id));
CREATE POLICY messages_send ON messages FOR INSERT TO rejnox_app
  WITH CHECK (sender_id = app_user_id() AND is_conversation_member(conversation_id));

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY bookings_access ON bookings TO rejnox_app
  USING (trainer_id = app_user_id() OR can_access_client(trainer_client_id))
  WITH CHECK (can_access_client(trainer_client_id));

ALTER TABLE member_passes ENABLE ROW LEVEL SECURITY;
CREATE POLICY member_passes_self ON member_passes TO rejnox_app
  USING (user_id = app_user_id()) WITH CHECK (user_id = app_user_id());

-- Verejné čítanie pre prihlásených, zápis len vlastných záznamov.
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;
CREATE POLICY gyms_read ON gyms FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY gyms_insert ON gyms FOR INSERT TO rejnox_app
  WITH CHECK (created_by = app_user_id());
CREATE POLICY gyms_update ON gyms FOR UPDATE TO rejnox_app
  USING (created_by = app_user_id()) WITH CHECK (created_by = app_user_id());
CREATE POLICY gyms_delete ON gyms FOR DELETE TO rejnox_app
  USING (created_by = app_user_id());

ALTER TABLE gym_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY gym_prices_read ON gym_prices FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY gym_prices_insert ON gym_prices FOR INSERT TO rejnox_app
  WITH CHECK (submitted_by = app_user_id());
CREATE POLICY gym_prices_update ON gym_prices FOR UPDATE TO rejnox_app
  USING (submitted_by = app_user_id()) WITH CHECK (submitted_by = app_user_id());
CREATE POLICY gym_prices_delete ON gym_prices FOR DELETE TO rejnox_app
  USING (submitted_by = app_user_id());

ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY exercises_read ON exercises FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY exercises_insert ON exercises FOR INSERT TO rejnox_app
  WITH CHECK (created_by = app_user_id());

ALTER TABLE partner_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY partner_sessions_read ON partner_sessions FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY partner_sessions_insert ON partner_sessions FOR INSERT TO rejnox_app
  WITH CHECK (host_id = app_user_id());
CREATE POLICY partner_sessions_update ON partner_sessions FOR UPDATE TO rejnox_app
  USING (host_id = app_user_id()) WITH CHECK (host_id = app_user_id());
CREATE POLICY partner_sessions_delete ON partner_sessions FOR DELETE TO rejnox_app
  USING (host_id = app_user_id());

ALTER TABLE partner_session_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY psm_read ON partner_session_members FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY psm_join ON partner_session_members FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id());
CREATE POLICY psm_leave ON partner_session_members FOR DELETE TO rejnox_app
  USING (user_id = app_user_id());
