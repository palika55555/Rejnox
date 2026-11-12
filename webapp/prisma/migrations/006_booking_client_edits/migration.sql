-- Rejnox: klient smie potvrdený termín už len zrušiť, nie presunúť.

CREATE OR REPLACE FUNCTION bookings_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link_trainer uuid;
  me uuid := app_user_id();
BEGIN
  SELECT trainer_id INTO link_trainer
  FROM trainer_clients WHERE id = NEW.trainer_client_id;

  IF link_trainer IS DISTINCT FROM NEW.trainer_id THEN
    RAISE EXCEPTION 'booking trainer does not match client link'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Tréner smie všetko (okrem zmeny vlastníka nižšie).
  IF me IS NOT DISTINCT FROM NEW.trainer_id THEN
    IF TG_OP = 'UPDATE' AND (
         NEW.trainer_id <> OLD.trainer_id
         OR NEW.trainer_client_id <> OLD.trainer_client_id) THEN
      RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  -- Klient: nový termín len ako žiadosť.
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'requested' THEN
      RAISE EXCEPTION 'client can only request a booking'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.trainer_id <> OLD.trainer_id
     OR NEW.trainer_client_id <> OLD.trainer_client_id
     OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Klient smie: (a) zrušiť termín bez ďalších zmien,
  --              (b) upraviť čas žiadosti, ktorú tréner ešte nepotvrdil.
  IF NEW.status = 'cancelled' AND OLD.status <> 'cancelled'
     AND NEW.during = OLD.during THEN
    RETURN NEW;
  END IF;
  IF OLD.status = 'requested' AND NEW.status = 'requested' THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'client can only cancel or edit a pending request'
    USING ERRCODE = 'insufficient_privilege';
END
$$;
