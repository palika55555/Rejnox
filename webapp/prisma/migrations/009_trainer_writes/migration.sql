-- Rejnox: tréner a klienti.
-- 1) Klientov smie pridávať len účet s rolou tréner.
-- 2) Plány a série v rámci spolupráce zapisuje len tréner (kým trvá);
--    klient ich vidí, ale nemení. Vlastné záznamy si každý spravuje sám.

-- Je prihlásený trénerom tejto spolupráce a spolupráca ešte trvá?
CREATE FUNCTION is_active_trainer_of(tc_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trainer_clients t
    WHERE t.id = tc_id AND t.trainer_id = app_user_id() AND t.status <> 'ended'
  )
$$;

REVOKE ALL ON FUNCTION is_active_trainer_of(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_active_trainer_of(uuid) TO rejnox_app;

-- Pridanie klienta: len tréner.
CREATE FUNCTION trainer_clients_role_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users WHERE id = NEW.trainer_id AND role = 'trainer'
  ) THEN
    RAISE EXCEPTION 'only trainers can add clients'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION trainer_clients_role_guard() FROM PUBLIC;

CREATE TRIGGER trainer_clients_role_guard
BEFORE INSERT ON trainer_clients
FOR EACH ROW EXECUTE FUNCTION trainer_clients_role_guard();

-- Tréningy (plány).
DROP POLICY workouts_access ON workouts;
CREATE POLICY workouts_read ON workouts FOR SELECT TO rejnox_app
  USING (user_id = app_user_id() OR can_access_client(trainer_client_id));
CREATE POLICY workouts_insert ON workouts FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));
CREATE POLICY workouts_update ON workouts FOR UPDATE TO rejnox_app
  USING (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id))
  WITH CHECK (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));
CREATE POLICY workouts_delete ON workouts FOR DELETE TO rejnox_app
  USING (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));

-- Cviky v pláne: zapisovať smie ten, kto smie zapisovať do plánu.
DROP POLICY workout_exercises_access ON workout_exercises;
CREATE POLICY workout_exercises_read ON workout_exercises FOR SELECT TO rejnox_app
  USING (EXISTS (SELECT 1 FROM workouts w WHERE w.id = workout_id));
CREATE POLICY workout_exercises_write ON workout_exercises TO rejnox_app
  USING (EXISTS (
    SELECT 1 FROM workouts w WHERE w.id = workout_id
      AND (w.user_id = app_user_id() OR is_active_trainer_of(w.trainer_client_id))))
  WITH CHECK (EXISTS (
    SELECT 1 FROM workouts w WHERE w.id = workout_id
      AND (w.user_id = app_user_id() OR is_active_trainer_of(w.trainer_client_id))));

-- Odcvičené série.
DROP POLICY set_logs_access ON set_logs;
CREATE POLICY set_logs_read ON set_logs FOR SELECT TO rejnox_app
  USING (user_id = app_user_id() OR can_access_client(trainer_client_id));
CREATE POLICY set_logs_insert ON set_logs FOR INSERT TO rejnox_app
  WITH CHECK (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));
CREATE POLICY set_logs_update ON set_logs FOR UPDATE TO rejnox_app
  USING (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id))
  WITH CHECK (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));
CREATE POLICY set_logs_delete ON set_logs FOR DELETE TO rejnox_app
  USING (user_id = app_user_id() OR is_active_trainer_of(trainer_client_id));
