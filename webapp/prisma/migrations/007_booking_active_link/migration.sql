-- Rejnox: rezervácie len pri aktívnej spolupráci a mazanie len trénerom.

CREATE OR REPLACE FUNCTION bookings_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
  me uuid := app_user_id();
BEGIN
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;

  IF link.trainer_id IS DISTINCT FROM NEW.trainer_id THEN
    RAISE EXCEPTION 'booking trainer does not match client link'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Tréner smie všetko okrem zmeny vlastníka.
  IF me IS NOT DISTINCT FROM NEW.trainer_id THEN
    IF TG_OP = 'UPDATE' AND (
         NEW.trainer_id <> OLD.trainer_id
         OR NEW.trainer_client_id <> OLD.trainer_client_id) THEN
      RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND (
       NEW.trainer_id <> OLD.trainer_id
       OR NEW.trainer_client_id <> OLD.trainer_client_id
       OR NEW.created_at <> OLD.created_at) THEN
    RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Zrušiť vlastný termín smie klient vždy (aj po ukončení spolupráce).
  IF TG_OP = 'UPDATE' AND NEW.status = 'cancelled' AND OLD.status <> 'cancelled'
     AND NEW.during = OLD.during AND link.client_user_id = me THEN
    RETURN NEW;
  END IF;

  -- Všetko ostatné len pri aktívnej spolupráci.
  IF link.status <> 'linked' OR link.client_user_id IS DISTINCT FROM me THEN
    RAISE EXCEPTION 'no active link with this trainer'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'requested' THEN
      RAISE EXCEPTION 'client can only request a booking'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  -- Úprava času je možná len pri žiadosti, ktorú tréner ešte nepotvrdil.
  IF OLD.status = 'requested' AND NEW.status = 'requested' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'client can only cancel or edit a pending request'
    USING ERRCODE = 'insufficient_privilege';
END
$$;

-- Jedna politika pre všetko nahradená samostatnými; mazať smie len tréner.
DROP POLICY bookings_access ON bookings;
CREATE POLICY bookings_select ON bookings FOR SELECT TO rejnox_app
  USING (trainer_id = app_user_id() OR can_access_client(trainer_client_id));
CREATE POLICY bookings_insert ON bookings FOR INSERT TO rejnox_app
  WITH CHECK (can_access_client(trainer_client_id));
CREATE POLICY bookings_update ON bookings FOR UPDATE TO rejnox_app
  USING (trainer_id = app_user_id() OR can_access_client(trainer_client_id))
  WITH CHECK (can_access_client(trainer_client_id));
CREATE POLICY bookings_delete ON bookings FOR DELETE TO rejnox_app
  USING (trainer_id = app_user_id());
