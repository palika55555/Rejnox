-- Rejnox: sprísnenie prepojenia tréner – klient a rezervácií.

-- 1) Prepojený klient sa nedá znova "pozvať" ani prepísať na iný účet.
CREATE OR REPLACE FUNCTION trainer_clients_guard() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Funkcie so SECURITY DEFINER (prijatie pozvánky) bežia ako vlastník a prejdú.
  IF current_user <> 'rejnox_app' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.client_user_id IS NOT NULL OR NEW.status NOT IN ('record_only', 'invited') THEN
      RAISE EXCEPTION 'client must accept an invite to be linked'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.trainer_id <> OLD.trainer_id
     OR NEW.client_user_id IS DISTINCT FROM OLD.client_user_id
     OR (OLD.status = 'ended' AND NEW.status <> 'ended')
     OR (NEW.status = 'linked' AND OLD.status <> 'linked') THEN
    RAISE EXCEPTION 'link change not allowed' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Keď je k záznamu pripojený účet klienta, dá sa už len ukončiť.
  -- Žiadna nová pozvánka, žiadny návrat do stavu "pozvaný".
  IF OLD.client_user_id IS NOT NULL THEN
    IF NEW.status NOT IN (OLD.status, 'ended')
       OR NEW.invite_token_hash IS NOT NULL
       OR NEW.invite_expires_at IS NOT NULL THEN
      RAISE EXCEPTION 'linked client can only be ended'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;

  -- Klient smie jediné: ukončiť spoluprácu.
  IF app_user_id() = OLD.client_user_id AND app_user_id() <> OLD.trainer_id THEN
    IF NEW.status <> 'ended'
       OR NEW.client_name <> OLD.client_name
       OR NEW.note IS DISTINCT FROM OLD.note
       OR NEW.invite_token_hash IS DISTINCT FROM OLD.invite_token_hash
       OR NEW.invite_expires_at IS DISTINCT FROM OLD.invite_expires_at THEN
      RAISE EXCEPTION 'client can only end the link' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END
$$;

CREATE OR REPLACE FUNCTION accept_client_invite(p_token_hash text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  link uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  UPDATE trainer_clients
  SET client_user_id = me, status = 'linked',
      invite_token_hash = NULL, invite_expires_at = NULL
  WHERE invite_token_hash = p_token_hash
    AND status = 'invited'
    AND client_user_id IS NULL
    AND invite_expires_at > now()
    AND trainer_id <> me
  RETURNING id INTO link;

  IF link IS NULL THEN
    RAISE EXCEPTION 'invite invalid or expired';
  END IF;
  RETURN link;
END
$$;

-- 2) Tréner smie zmazať len klienta bez účtu (záznam / nevybavená pozvánka).
--    Históriu prepojeného klienta zmazať nevie; spoluprácu môže len ukončiť.
DROP POLICY tc_delete ON trainer_clients;
CREATE POLICY tc_delete ON trainer_clients FOR DELETE TO rejnox_app
  USING (trainer_id = app_user_id() AND client_user_id IS NULL);

-- 3) Rezervácia musí patriť trénerovi daného klienta a potvrdiť ju smie len tréner.
CREATE FUNCTION bookings_guard() RETURNS trigger
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

  IF TG_OP = 'UPDATE' AND (
       NEW.trainer_id <> OLD.trainer_id
       OR NEW.trainer_client_id <> OLD.trainer_client_id) THEN
    RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Klient môže termín len žiadať alebo zrušiť; potvrdzuje tréner.
  IF me IS DISTINCT FROM NEW.trainer_id AND NEW.status = 'confirmed'
     AND (TG_OP = 'INSERT' OR OLD.status <> 'confirmed') THEN
    RAISE EXCEPTION 'only the trainer can confirm' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION bookings_guard() FROM PUBLIC;

CREATE TRIGGER bookings_guard
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION bookings_guard();
