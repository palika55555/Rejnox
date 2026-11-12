-- Rejnox: ochrana prepojenia tréner – klient.
-- Tréner si nemôže sám "priradiť" cudzí účet ani obnoviť spoluprácu, ktorú klient ukončil.
-- Prepojenie vzniká len tak, že klient prijme pozvánku.

CREATE FUNCTION trainer_clients_guard() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Funkcie so SECURITY DEFINER (napr. prijatie pozvánky) bežia ako vlastník a prejdú.
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

CREATE TRIGGER trainer_clients_guard
BEFORE INSERT OR UPDATE ON trainer_clients
FOR EACH ROW EXECUTE FUNCTION trainer_clients_guard();

-- Klient prijme pozvánku: jeho účet sa prepojí so záznamom, ktorý mu tréner založil.
CREATE FUNCTION accept_client_invite(p_token_hash text) RETURNS uuid
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
    AND invite_expires_at > now()
    AND trainer_id <> me
  RETURNING id INTO link;

  IF link IS NULL THEN
    RAISE EXCEPTION 'invite invalid or expired';
  END IF;
  RETURN link;
END
$$;

REVOKE ALL ON FUNCTION accept_client_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION accept_client_invite(text) TO rejnox_app;
