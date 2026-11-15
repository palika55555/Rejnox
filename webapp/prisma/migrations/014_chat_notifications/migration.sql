-- Rejnox: chat medzi trénerom a klientom a upozornenia v appke.
-- 1) Každé prepojenie tréner–klient má jednu konverzáciu. Písať sa dá len
--    pri aktívnej spolupráci, staré správy po jej ukončení ostanú na čítanie.
-- 2) Prečítanie sa pamätá na člena konverzácie (last_read_at).
-- 3) Upozornenia (notifications) zapisujú len triggery v databáze, appka ich
--    smie čítať, označiť ako prečítané a zmazať.

-- ------------------------------------------------------------------ chat

ALTER TABLE conversations
  ADD COLUMN trainer_client_id uuid UNIQUE REFERENCES trainer_clients (id) ON DELETE CASCADE;

ALTER TABLE conversation_members
  ADD COLUMN last_read_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX messages_conversation_desc_idx ON messages (conversation_id, sent_at DESC);

-- Konverzácia k prepojeniu (založí ju pri prvom použití). Smie len tréner
-- alebo klient tohto prepojenia; založiť novú len pri aktívnej spolupráci.
CREATE FUNCTION link_conversation(p_link uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  link trainer_clients%ROWTYPE;
  conv uuid;
BEGIN
  SELECT * INTO link FROM trainer_clients WHERE id = p_link;
  IF link.id IS NULL OR me IS NULL
     OR (link.trainer_id <> me AND link.client_user_id IS DISTINCT FROM me) THEN
    RAISE EXCEPTION 'link not found' USING ERRCODE = 'no_data_found';
  END IF;

  SELECT id INTO conv FROM conversations WHERE trainer_client_id = p_link;
  IF conv IS NOT NULL THEN
    RETURN conv;
  END IF;
  IF link.status <> 'linked' OR link.client_user_id IS NULL THEN
    RAISE EXCEPTION 'no active link' USING ERRCODE = 'insufficient_privilege';
  END IF;

  INSERT INTO conversations (trainer_client_id) VALUES (p_link)
  ON CONFLICT (trainer_client_id) DO NOTHING
  RETURNING id INTO conv;
  IF conv IS NULL THEN
    -- Súbežne ju založila druhá strana.
    SELECT id INTO conv FROM conversations WHERE trainer_client_id = p_link;
  ELSE
    INSERT INTO conversation_members (conversation_id, user_id)
    VALUES (conv, link.trainer_id), (conv, link.client_user_id);
  END IF;
  RETURN conv;
END
$$;

-- Do konverzácie k prepojeniu sa píše len pri aktívnej spolupráci.
CREATE FUNCTION can_send_message(conv_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT is_conversation_member(conv_id) AND NOT EXISTS (
    SELECT 1 FROM conversations c
    JOIN trainer_clients t ON t.id = c.trainer_client_id
    WHERE c.id = conv_id AND t.status <> 'linked'
  )
$$;

DROP POLICY messages_send ON messages;
CREATE POLICY messages_send ON messages FOR INSERT TO rejnox_app
  WITH CHECK (sender_id = app_user_id() AND can_send_message(conversation_id));

-- Označí konverzáciu ako prečítanú prihláseným.
CREATE FUNCTION mark_conversation_read(conv_id uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  UPDATE conversation_members SET last_read_at = now()
  WHERE conversation_id = conv_id AND user_id = app_user_id()
$$;

-- ------------------------------------------------------------ upozornenia

CREATE TABLE notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (char_length(kind) BETWEEN 1 AND 40),
  title      text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  body       text CHECK (char_length(body) <= 300),
  -- Kam appka po ťuknutí prejde (prepojenie tréner–klient).
  link_id    uuid REFERENCES trainer_clients (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at    timestamptz
);
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);

CREATE FUNCTION notify(p_user uuid, p_kind text, p_title text, p_body text, p_link uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  INSERT INTO notifications (user_id, kind, title, body, link_id)
  SELECT p_user, p_kind, left(p_title, 120), left(p_body, 300), p_link
  WHERE p_user IS NOT NULL AND p_user IS DISTINCT FROM app_user_id()
$$;

CREATE FUNCTION display_name_of(p_user uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$ SELECT display_name FROM users WHERE id = p_user $$;

-- Nový plán od trénera → klient.
CREATE FUNCTION notify_new_workout() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
BEGIN
  IF NEW.trainer_client_id IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;
  PERFORM notify(link.client_user_id, 'plan', 'Nový plán od trénera',
    display_name_of(link.trainer_id) || ': ' || NEW.title, link.id);
  RETURN NULL;
END
$$;

CREATE TRIGGER notify_new_workout
AFTER INSERT ON workouts
FOR EACH ROW EXECUTE FUNCTION notify_new_workout();

-- Prijatá pozvánka → tréner, ukončená spolupráca → druhá strana.
CREATE FUNCTION notify_link_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NULL;
  END IF;
  IF NEW.status = 'linked' THEN
    PERFORM notify(NEW.trainer_id, 'link', 'Klient prijal pozvánku',
      NEW.client_name || ' sa prepojil s tebou v Rejnoxe.', NEW.id);
  ELSIF NEW.status = 'ended' AND OLD.status = 'linked' THEN
    IF app_user_id() IS NOT DISTINCT FROM NEW.trainer_id THEN
      PERFORM notify(NEW.client_user_id, 'link_ended', 'Spolupráca ukončená',
        display_name_of(NEW.trainer_id) || ' ukončil spoluprácu.', NEW.id);
    ELSE
      PERFORM notify(NEW.trainer_id, 'link_ended', 'Spolupráca ukončená',
        NEW.client_name || ' ukončil spoluprácu.', NEW.id);
    END IF;
  END IF;
  RETURN NULL;
END
$$;

CREATE TRIGGER notify_link_change
AFTER UPDATE OF status ON trainer_clients
FOR EACH ROW EXECUTE FUNCTION notify_link_change();

-- Rezervácie: žiadosť a rezervácia → tréner, potvrdenie a nový termín → klient,
-- zrušenie → druhá strana.
CREATE FUNCTION notify_booking() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
  by_trainer boolean := app_user_id() IS NOT DISTINCT FROM NEW.trainer_id;
  other uuid;
  who text;
  at text := to_char(lower(NEW.during) AT TIME ZONE 'Europe/Bratislava', 'DD. MM. HH24:MI');
BEGIN
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;
  other := CASE WHEN by_trainer THEN link.client_user_id ELSE NEW.trainer_id END;
  who := CASE WHEN by_trainer THEN display_name_of(NEW.trainer_id) ELSE link.client_name END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'cancelled' THEN
      RETURN NULL;
    ELSIF by_trainer THEN
      PERFORM notify(other, 'booking', 'Nový tréning v kalendári', who || ' ťa zapísal na ' || at || '.', link.id);
    ELSIF NEW.status = 'requested' THEN
      PERFORM notify(other, 'booking', 'Žiadosť o tréning', who || ' žiada o tréning ' || at || '.', link.id);
    ELSE
      PERFORM notify(other, 'booking', 'Nová rezervácia', who || ' si rezervoval termín ' || at || '.', link.id);
    END IF;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status = 'confirmed' AND by_trainer THEN
      PERFORM notify(other, 'booking', 'Tréning potvrdený', who || ' potvrdil tréning ' || at || '.', link.id);
    ELSIF NEW.status = 'cancelled' THEN
      PERFORM notify(other, 'booking', 'Tréning zrušený', who || ' zrušil tréning ' || at || '.', link.id);
    END IF;
  END IF;
  RETURN NULL;
END
$$;

CREATE TRIGGER notify_booking
AFTER INSERT OR UPDATE OF status ON bookings
FOR EACH ROW EXECUTE FUNCTION notify_booking();

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notifications_own ON notifications TO rejnox_app
  USING (user_id = app_user_id()) WITH CHECK (user_id = app_user_id());

-- ------------------------------------------------------------------ práva

REVOKE ALL ON FUNCTION link_conversation(uuid), can_send_message(uuid),
  mark_conversation_read(uuid), notify(uuid, text, text, text, uuid),
  display_name_of(uuid), notify_new_workout(), notify_link_change(),
  notify_booking() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION link_conversation(uuid), can_send_message(uuid),
  mark_conversation_read(uuid) TO rejnox_app;
-- Upozornenia vznikajú len v triggeroch, appka ich nevkladá.
GRANT SELECT, UPDATE (read_at), DELETE ON notifications TO rejnox_app;
