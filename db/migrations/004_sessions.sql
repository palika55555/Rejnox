-- Rejnox: prihlásenia (sessions) a zmazanie vlastného účtu.

-- Token sa do databázy neukladá, len jeho SHA-256 odtlačok.
CREATE TABLE sessions (
  token_hash text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);
CREATE INDEX sessions_user_idx ON sessions (user_id);

-- Komu patrí platný token? Volá sa skôr, než server vie, kto je prihlásený.
CREATE FUNCTION auth_session_user(p_token_hash text) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT s.user_id FROM sessions s
  WHERE s.token_hash = p_token_hash AND s.expires_at > now()
$$;

REVOKE ALL ON FUNCTION auth_session_user(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_session_user(text) TO rejnox_app;

GRANT SELECT, INSERT, DELETE ON sessions TO rejnox_app;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY sessions_self_select ON sessions FOR SELECT TO rejnox_app
  USING (user_id = app_user_id());
CREATE POLICY sessions_self_insert ON sessions FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id());
CREATE POLICY sessions_self_delete ON sessions FOR DELETE TO rejnox_app
  USING (user_id = app_user_id());

-- Každý si vie zmazať vlastný účet (a s ním všetky svoje údaje).
GRANT DELETE ON users TO rejnox_app;
CREATE POLICY users_self_delete ON users FOR DELETE TO rejnox_app
  USING (id = app_user_id());
