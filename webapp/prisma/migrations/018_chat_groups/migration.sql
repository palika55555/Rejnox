-- Rejnox: plnohodnotný chat – skupiny, súkromné správy a práca so správami.
-- 1) Konverzácia je jedného druhu: 'link' (tréner–klient, existujúca),
--    'direct' (dvaja ľudia, ktorí sa poznajú) alebo 'group' (skupina s názvom).
-- 2) Písať súkromne a pridávať do skupín sa dá len ľuďom, ktorých človek
--    pozná: aktívne prepojenie tréner–klient alebo spoločná skupina,
--    a nikto z nich toho druhého nezablokoval.
-- 3) Do skupiny sa dá pridať správcom alebo vstúpiť cez pozývací kód
--    (v databáze je len jeho odtlačok). Nový člen nevidí staršie správy.
-- 4) Správy: odpoveď na správu, úprava, zmazanie, reakcie, fotky,
--    systémové správy (vznikajú len vo funkciách nižšie, appka ich nevloží).
-- Všetky zmeny členstva a správ idú cez funkcie SECURITY DEFINER, ktoré
-- overia oprávnenie; appka (rejnox_app) do týchto tabuliek priamo nezapisuje.

-- ---------------------------------------------------------- konverzácie

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_kind') THEN
    CREATE TYPE conversation_kind AS ENUM ('link', 'direct', 'group');
  END IF;
END
$$;

ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS kind conversation_kind NOT NULL DEFAULT 'direct',
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES users (id) ON DELETE SET NULL,
  -- Dvojica pri súkromnej konverzácii ("menšie-uuid:väčšie-uuid"), nech je len jedna.
  ADD COLUMN IF NOT EXISTS direct_key text UNIQUE,
  -- Odtlačok (sha256) pozývacieho kódu skupiny, null = vstup cez kód vypnutý.
  ADD COLUMN IF NOT EXISTS invite_code_hash text UNIQUE,
  ADD COLUMN IF NOT EXISTS last_message_at timestamptz;

UPDATE conversations SET kind = 'link' WHERE trainer_client_id IS NOT NULL AND kind <> 'link';

-- Staré súkromné konverzácie zo start_conversation dostanú kľúč dvojice.
UPDATE conversations c SET direct_key = d.k
FROM (
  SELECT conversation_id, k, row_number() OVER (PARTITION BY k ORDER BY conversation_id) AS n
  FROM (
    SELECT conversation_id, min(user_id::text) || ':' || max(user_id::text) AS k
    FROM conversation_members GROUP BY conversation_id HAVING count(*) = 2
  ) pairs
) d
WHERE c.id = d.conversation_id AND d.n = 1 AND c.kind = 'direct' AND c.direct_key IS NULL;

UPDATE conversations c SET last_message_at = (SELECT max(sent_at) FROM messages m WHERE m.conversation_id = c.id)
WHERE last_message_at IS NULL;

ALTER TABLE conversations DROP CONSTRAINT IF EXISTS conversations_kind_shape;
ALTER TABLE conversations ADD CONSTRAINT conversations_kind_shape CHECK (
  (kind = 'link') = (trainer_client_id IS NOT NULL)
  AND (kind = 'group') = (title IS NOT NULL)
  AND (title IS NULL OR char_length(title) BETWEEN 1 AND 60)
  AND (kind = 'direct' OR direct_key IS NULL)
  AND (kind = 'group' OR invite_code_hash IS NULL)
);
CREATE INDEX IF NOT EXISTS conversations_last_message_idx ON conversations (last_message_at DESC);

-- ---------------------------------------------------------------- členovia

ALTER TABLE conversation_members
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'member',
  -- Od kedy člen vidí správy. Doterajší členovia vidia celú históriu.
  ADD COLUMN IF NOT EXISTS joined_at timestamptz NOT NULL DEFAULT '-infinity',
  ADD COLUMN IF NOT EXISTS muted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS typing_until timestamptz;
ALTER TABLE conversation_members ALTER COLUMN joined_at SET DEFAULT clock_timestamp();
ALTER TABLE conversation_members DROP CONSTRAINT IF EXISTS conversation_members_role_check;
ALTER TABLE conversation_members ADD CONSTRAINT conversation_members_role_check CHECK (role IN ('admin', 'member'));

-- ------------------------------------------------------------------- správy

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS reply_to uuid REFERENCES messages (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  -- Posledná zmena (nová správa, úprava, zmazanie, reakcia): kurzor pre ?since=.
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT clock_timestamp();
UPDATE messages SET updated_at = sent_at WHERE updated_at > sent_at AND edited_at IS NULL AND deleted_at IS NULL;

ALTER TABLE messages ALTER COLUMN body DROP NOT NULL;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_body_check;
ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_shape;
ALTER TABLE messages ADD CONSTRAINT messages_shape CHECK (
  kind IN ('text', 'image', 'system')
  AND (body IS NULL OR char_length(body) BETWEEN 1 AND 4000)
  AND (deleted_at IS NOT NULL OR kind = 'image' OR body IS NOT NULL)
  AND (deleted_at IS NULL OR body IS NULL)
);
CREATE INDEX IF NOT EXISTS messages_updated_idx ON messages (conversation_id, updated_at);

-- Fotky v správach (rovnaké limity ako fotky fitiek).
CREATE TABLE IF NOT EXISTS message_images (
  message_id   uuid PRIMARY KEY REFERENCES messages (id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
  data         bytea NOT NULL CHECK (octet_length(data) BETWEEN 1 AND 1500000)
);

-- Jedna reakcia od človeka na správu, z pevného zoznamu.
CREATE TABLE IF NOT EXISTS message_reactions (
  message_id uuid NOT NULL REFERENCES messages (id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  emoji      text NOT NULL CHECK (emoji IN ('👍', '❤️', '😂', '😮', '😢', '🔥', '💪', '👏')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);
CREATE INDEX IF NOT EXISTS message_reactions_user_idx ON message_reactions (user_id);

-- Blokovanie: zablokovaný mi nenapíše súkromne ani ma nepridá do skupiny.
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS user_blocks_blocked_idx ON user_blocks (blocked_id);

-- ------------------------------------------------------ pomocné funkcie

-- Od kedy prihlásený vidí správy v konverzácii (null = nie je členom).
CREATE OR REPLACE FUNCTION member_joined_at(conv_id uuid) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT joined_at FROM conversation_members
  WHERE conversation_id = conv_id AND user_id = app_user_id()
$$;

CREATE OR REPLACE FUNCTION is_group_admin(conv_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM conversation_members cm JOIN conversations c ON c.id = cm.conversation_id
    WHERE cm.conversation_id = conv_id AND cm.user_id = app_user_id()
      AND cm.role = 'admin' AND c.kind = 'group'
  )
$$;

CREATE OR REPLACE FUNCTION is_blocked_between(a uuid, b uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_blocks
    WHERE (blocker_id = a AND blocked_id = b) OR (blocker_id = b AND blocked_id = a)
  )
$$;

-- Pozná prihlásený tohto človeka? (aktívne prepojenie alebo spoločná skupina,
-- bez blokovania). Len takým sa dá písať súkromne a pridávať ich do skupín.
CREATE OR REPLACE FUNCTION chat_can_contact(other uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT app_user_id() IS NOT NULL AND other IS NOT NULL AND other <> app_user_id()
    AND NOT is_blocked_between(app_user_id(), other)
    AND (
      EXISTS (
        SELECT 1 FROM trainer_clients t
        WHERE t.status = 'linked'
          AND ((t.trainer_id = app_user_id() AND t.client_user_id = other)
            OR (t.client_user_id = app_user_id() AND t.trainer_id = other))
      )
      OR EXISTS (
        SELECT 1 FROM conversation_members a
        JOIN conversation_members b ON b.conversation_id = a.conversation_id
        JOIN conversations c ON c.id = a.conversation_id
        WHERE c.kind = 'group' AND a.user_id = app_user_id() AND b.user_id = other
      )
    )
$$;

-- Ľudia, ktorým prihlásený môže písať (pre výber v appke).
CREATE OR REPLACE FUNCTION chat_contacts() RETURNS TABLE (id uuid, display_name text, role user_role)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT u.id, u.display_name, u.role FROM users u
  WHERE u.id IN (
    SELECT CASE WHEN t.trainer_id = app_user_id() THEN t.client_user_id ELSE t.trainer_id END
    FROM trainer_clients t
    WHERE t.status = 'linked' AND (t.trainer_id = app_user_id() OR t.client_user_id = app_user_id())
    UNION
    SELECT b.user_id FROM conversation_members a
    JOIN conversation_members b ON b.conversation_id = a.conversation_id
    JOIN conversations c ON c.id = a.conversation_id
    WHERE c.kind = 'group' AND a.user_id = app_user_id()
  )
  AND u.id <> app_user_id()
  AND NOT is_blocked_between(app_user_id(), u.id)
  ORDER BY lower(u.display_name)
$$;

-- Dá sa do konverzácie písať? Prepojenie: len pri aktívnej spolupráci.
-- Dvojice (prepojenie aj súkromná): nikto nezablokoval toho druhého.
-- Súkromná navyše len kým sa poznajú (napr. po odobratí zo spoločnej skupiny už nie).
CREATE OR REPLACE FUNCTION can_send_message(conv_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT is_conversation_member(conv_id)
    AND NOT EXISTS (
      SELECT 1 FROM conversations c
      JOIN trainer_clients t ON t.id = c.trainer_client_id
      WHERE c.id = conv_id AND t.status <> 'linked'
    )
    AND NOT EXISTS (
      SELECT 1 FROM conversations c
      JOIN conversation_members o ON o.conversation_id = c.id AND o.user_id <> app_user_id()
      WHERE c.id = conv_id AND c.kind <> 'group'
        AND (is_blocked_between(app_user_id(), o.user_id)
             OR (c.kind = 'direct' AND NOT chat_can_contact(o.user_id)))
    )
$$;

-- Správa, na ktorú sa odpovedá, musí byť v tej istej konverzácii.
CREATE OR REPLACE FUNCTION message_in_conversation(msg_id uuid, conv_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM messages m
    WHERE m.id = msg_id AND m.conversation_id = conv_id
      AND m.sent_at >= coalesce(member_joined_at(conv_id), 'infinity')
  )
$$;

-- Systémová správa v skupine (napr. "Jana pridala Petra").
CREATE OR REPLACE FUNCTION chat_system_message(conv_id uuid, p_body text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  INSERT INTO messages (conversation_id, sender_id, body, kind)
  VALUES (conv_id, app_user_id(), left(p_body, 4000), 'system')
$$;

-- Čas poslednej správy pre poradie zoznamu konverzácií.
CREATE OR REPLACE FUNCTION touch_conversation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE conversations SET last_message_at = NEW.sent_at
  WHERE id = NEW.conversation_id AND (last_message_at IS NULL OR last_message_at < NEW.sent_at);
  -- Kto odoslal, už nepíše.
  UPDATE conversation_members SET typing_until = NULL
  WHERE conversation_id = NEW.conversation_id AND user_id = NEW.sender_id AND typing_until IS NOT NULL;
  RETURN NULL;
END
$$;

DROP TRIGGER IF EXISTS touch_conversation ON messages;
CREATE TRIGGER touch_conversation
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION touch_conversation();

-- Konverzácia k prepojeniu (zo 014), teraz s druhom 'link'.
CREATE OR REPLACE FUNCTION link_conversation(p_link uuid) RETURNS uuid
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

  INSERT INTO conversations (kind, trainer_client_id) VALUES ('link', p_link)
  ON CONFLICT (trainer_client_id) DO NOTHING
  RETURNING id INTO conv;
  IF conv IS NULL THEN
    -- Súbežne ju založila druhá strana.
    SELECT id INTO conv FROM conversations WHERE trainer_client_id = p_link;
  ELSE
    INSERT INTO conversation_members (conversation_id, user_id, joined_at)
    VALUES (conv, link.trainer_id, '-infinity'), (conv, link.client_user_id, '-infinity');
  END IF;
  RETURN conv;
END
$$;

-- ------------------------------------------------------- súkromné správy

-- Nájde alebo založí súkromnú konverzáciu. S trénerom/klientom pri aktívnej
-- spolupráci vráti ich konverzáciu k prepojeniu (nech nie sú dve).
CREATE OR REPLACE FUNCTION start_direct(other uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  link_id uuid;
  k text;
  conv uuid;
BEGIN
  IF NOT chat_can_contact(other) THEN
    RAISE EXCEPTION 'not a contact' USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT t.id INTO link_id FROM trainer_clients t
  WHERE t.status = 'linked'
    AND ((t.trainer_id = me AND t.client_user_id = other) OR (t.client_user_id = me AND t.trainer_id = other))
  LIMIT 1;
  IF link_id IS NOT NULL THEN
    RETURN link_conversation(link_id);
  END IF;

  k := least(me, other)::text || ':' || greatest(me, other)::text;
  SELECT id INTO conv FROM conversations WHERE direct_key = k;
  IF conv IS NOT NULL THEN
    RETURN conv;
  END IF;

  INSERT INTO conversations (kind, direct_key, created_by) VALUES ('direct', k, me)
  ON CONFLICT (direct_key) DO NOTHING
  RETURNING id INTO conv;
  IF conv IS NULL THEN
    SELECT id INTO conv FROM conversations WHERE direct_key = k;
  ELSE
    INSERT INTO conversation_members (conversation_id, user_id, joined_at)
    VALUES (conv, me, '-infinity'), (conv, other, '-infinity');
  END IF;
  RETURN conv;
END
$$;

-- --------------------------------------------------------------- skupiny

-- Do skupiny najviac toľko ľudí.
CREATE OR REPLACE FUNCTION chat_group_max() RETURNS integer
LANGUAGE sql IMMUTABLE AS $$ SELECT 100 $$;

CREATE OR REPLACE FUNCTION chat_clean_title(p_title text) RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  t text := btrim(regexp_replace(coalesce(p_title, ''), '\s+', ' ', 'g'));
BEGIN
  IF char_length(t) NOT BETWEEN 1 AND 60 THEN
    RAISE EXCEPTION 'invalid title' USING ERRCODE = 'check_violation';
  END IF;
  RETURN t;
END
$$;

-- Pridá ľudí do skupiny (volajú create_group a add_group_members).
CREATE OR REPLACE FUNCTION chat_add_members(conv_id uuid, p_users uuid[]) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  u uuid;
  added integer := 0;
BEGIN
  -- Súbežné pridávania do tej istej skupiny idú po jednom (limit členov).
  PERFORM 1 FROM conversations WHERE id = conv_id FOR UPDATE;
  FOR u IN SELECT DISTINCT x FROM unnest(coalesce(p_users, '{}')) AS x WHERE x IS NOT NULL AND x <> app_user_id() LOOP
    IF EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conv_id AND user_id = u) THEN
      CONTINUE;
    END IF;
    IF NOT chat_can_contact(u) THEN
      RAISE EXCEPTION 'not a contact' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, last_read_at)
    VALUES (conv_id, u, 'member', clock_timestamp(), clock_timestamp());
    PERFORM chat_system_message(conv_id, display_name_of(app_user_id()) || ' pridal(a) ' || display_name_of(u) || '.');
    added := added + 1;
  END LOOP;
  IF (SELECT count(*) FROM conversation_members WHERE conversation_id = conv_id) > chat_group_max() THEN
    RAISE EXCEPTION 'group full' USING ERRCODE = 'program_limit_exceeded';
  END IF;
  RETURN added;
END
$$;

CREATE OR REPLACE FUNCTION create_group(p_title text, p_members uuid[]) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  t text := chat_clean_title(p_title);
  conv uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO conversations (kind, title, created_by) VALUES ('group', t, me) RETURNING id INTO conv;
  INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, last_read_at)
  VALUES (conv, me, 'admin', clock_timestamp(), clock_timestamp());
  PERFORM chat_system_message(conv, display_name_of(me) || ' vytvoril(a) skupinu „' || t || '“.');
  PERFORM chat_add_members(conv, p_members);
  RETURN conv;
END
$$;

CREATE OR REPLACE FUNCTION add_group_members(conv_id uuid, p_users uuid[]) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN chat_add_members(conv_id, p_users);
END
$$;

-- Odchod zo skupiny (p_user = ja) alebo odobratie člena správcom.
-- Keď odíde posledný správca, správcom sa stane najdlhší člen;
-- keď odíde posledný človek, skupina zanikne.
CREATE OR REPLACE FUNCTION remove_group_member(conv_id uuid, p_user uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  next_admin uuid;
BEGIN
  -- Súbežné odchody správcov idú po jednom, aby skupina neostala bez správcu.
  PERFORM 1 FROM conversations WHERE id = conv_id FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM conversations WHERE id = conv_id AND kind = 'group')
     OR NOT is_conversation_member(conv_id) THEN
    RAISE EXCEPTION 'group not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_user IS DISTINCT FROM me AND NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conv_id AND user_id = p_user) THEN
    RAISE EXCEPTION 'member not found' USING ERRCODE = 'no_data_found';
  END IF;

  IF p_user = me THEN
    PERFORM chat_system_message(conv_id, display_name_of(me) || ' opustil(a) skupinu.');
  ELSE
    PERFORM chat_system_message(conv_id, display_name_of(me) || ' odobral(a) ' || display_name_of(p_user) || '.');
    -- Odobratý by sa inak vrátil starým kódom; správca vytvorí nový.
    UPDATE conversations SET invite_code_hash = NULL WHERE id = conv_id;
  END IF;
  DELETE FROM conversation_members WHERE conversation_id = conv_id AND user_id = p_user;

  IF NOT EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conv_id) THEN
    DELETE FROM conversations WHERE id = conv_id;
  ELSIF NOT EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conv_id AND role = 'admin') THEN
    SELECT user_id INTO next_admin FROM conversation_members
    WHERE conversation_id = conv_id ORDER BY joined_at, user_id LIMIT 1;
    UPDATE conversation_members SET role = 'admin' WHERE conversation_id = conv_id AND user_id = next_admin;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION set_group_role(conv_id uuid, p_user uuid, p_role text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM 1 FROM conversations WHERE id = conv_id FOR UPDATE;
  IF NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_role NOT IN ('admin', 'member') THEN
    RAISE EXCEPTION 'invalid role' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE conversation_members SET role = p_role WHERE conversation_id = conv_id AND user_id = p_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'member not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conv_id AND role = 'admin') THEN
    RAISE EXCEPTION 'last admin' USING ERRCODE = 'check_violation';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION rename_group(conv_id uuid, p_title text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  t text := chat_clean_title(p_title);
BEGIN
  IF NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE conversations SET title = t WHERE id = conv_id AND title IS DISTINCT FROM t;
  IF FOUND THEN
    PERFORM chat_system_message(conv_id, display_name_of(app_user_id()) || ' premenoval(a) skupinu na „' || t || '“.');
  END IF;
END
$$;

-- Nový pozývací kód (odtlačok), null kód vypne.
CREATE OR REPLACE FUNCTION set_group_invite(conv_id uuid, p_hash text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE conversations SET invite_code_hash = p_hash WHERE id = conv_id;
END
$$;

CREATE OR REPLACE FUNCTION join_group_by_code(p_hash text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  me uuid := app_user_id();
  conv uuid;
BEGIN
  SELECT id INTO conv FROM conversations WHERE kind = 'group' AND invite_code_hash = p_hash AND p_hash IS NOT NULL
  FOR UPDATE;
  IF conv IS NULL OR me IS NULL THEN
    RAISE EXCEPTION 'invite invalid' USING ERRCODE = 'no_data_found';
  END IF;
  IF is_conversation_member(conv) THEN
    RETURN conv;
  END IF;
  IF (SELECT count(*) FROM conversation_members WHERE conversation_id = conv) >= chat_group_max() THEN
    RAISE EXCEPTION 'group full' USING ERRCODE = 'program_limit_exceeded';
  END IF;
  INSERT INTO conversation_members (conversation_id, user_id, role, joined_at, last_read_at)
  VALUES (conv, me, 'member', clock_timestamp(), clock_timestamp());
  PERFORM chat_system_message(conv, display_name_of(me) || ' sa pridal(a) cez pozývací kód.');
  RETURN conv;
END
$$;

CREATE OR REPLACE FUNCTION delete_group(conv_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_group_admin(conv_id) THEN
    RAISE EXCEPTION 'not admin' USING ERRCODE = 'insufficient_privilege';
  END IF;
  DELETE FROM conversations WHERE id = conv_id;
END
$$;

-- ----------------------------------------------------- práca so správami

CREATE OR REPLACE FUNCTION edit_message(msg_id uuid, p_body text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  m messages%ROWTYPE;
BEGIN
  SELECT * INTO m FROM messages WHERE id = msg_id;
  IF m.id IS NULL OR m.sender_id IS DISTINCT FROM app_user_id() OR m.kind <> 'text' OR m.deleted_at IS NOT NULL
     OR m.sent_at < coalesce(member_joined_at(m.conversation_id), 'infinity') THEN
    RAISE EXCEPTION 'message not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF NOT can_send_message(m.conversation_id) THEN
    RAISE EXCEPTION 'cannot send' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF char_length(btrim(coalesce(p_body, ''))) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'invalid body' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE messages SET body = btrim(p_body), edited_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = msg_id AND body IS DISTINCT FROM btrim(p_body);
END
$$;

-- Zmaže vlastnú správu; správca skupiny aj cudziu. Ostane po nej len značka.
CREATE OR REPLACE FUNCTION delete_message(msg_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  m messages%ROWTYPE;
BEGIN
  SELECT * INTO m FROM messages WHERE id = msg_id;
  IF m.id IS NULL OR m.kind = 'system'
     OR m.sent_at < coalesce(member_joined_at(m.conversation_id), 'infinity')
     OR (m.sender_id IS DISTINCT FROM app_user_id() AND NOT is_group_admin(m.conversation_id)) THEN
    RAISE EXCEPTION 'message not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF m.deleted_at IS NOT NULL THEN
    RETURN;
  END IF;
  DELETE FROM message_images WHERE message_id = msg_id;
  DELETE FROM message_reactions WHERE message_id = msg_id;
  UPDATE messages SET body = NULL, deleted_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE id = msg_id;
END
$$;

-- Reakcia na správu; null emoji reakciu odoberie.
CREATE OR REPLACE FUNCTION react_message(msg_id uuid, p_emoji text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  m messages%ROWTYPE;
BEGIN
  SELECT * INTO m FROM messages WHERE id = msg_id;
  IF m.id IS NULL OR m.kind = 'system' OR m.deleted_at IS NOT NULL
     OR m.sent_at < coalesce(member_joined_at(m.conversation_id), 'infinity') THEN
    RAISE EXCEPTION 'message not found' USING ERRCODE = 'no_data_found';
  END IF;
  IF NOT can_send_message(m.conversation_id) THEN
    RAISE EXCEPTION 'cannot send' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_emoji IS NULL THEN
    DELETE FROM message_reactions WHERE message_id = msg_id AND user_id = app_user_id();
  ELSE
    INSERT INTO message_reactions (message_id, user_id, emoji) VALUES (msg_id, app_user_id(), p_emoji)
    ON CONFLICT (message_id, user_id) DO UPDATE SET emoji = EXCLUDED.emoji, created_at = now();
  END IF;
  UPDATE messages SET updated_at = clock_timestamp() WHERE id = msg_id;
END
$$;

CREATE OR REPLACE FUNCTION set_typing(conv_id uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  UPDATE conversation_members SET typing_until = clock_timestamp() + interval '6 seconds'
  WHERE conversation_id = conv_id AND user_id = app_user_id() AND can_send_message(conv_id)
$$;

CREATE OR REPLACE FUNCTION set_conversation_muted(conv_id uuid, p_muted boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE conversation_members SET muted = coalesce(p_muted, false)
  WHERE conversation_id = conv_id AND user_id = app_user_id();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation not found' USING ERRCODE = 'no_data_found';
  END IF;
END
$$;

-- Prečítanie: posúva sa len dopredu (nahrádza verziu zo 016, rovnaké správanie).
CREATE OR REPLACE FUNCTION mark_conversation_read(conv_id uuid, up_to timestamptz) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  UPDATE conversation_members SET last_read_at = greatest(last_read_at, up_to)
  WHERE conversation_id = conv_id AND user_id = app_user_id() AND up_to IS NOT NULL
$$;

-- ------------------------------------------------------- Row Level Security

-- Člen vidí správy len od chvíle, keď do konverzácie prišiel.
DROP POLICY IF EXISTS messages_read ON messages;
CREATE POLICY messages_read ON messages FOR SELECT TO rejnox_app
  USING (sent_at >= member_joined_at(conversation_id));

-- Appka vkladá len text alebo fotku, vlastným menom, nezmazané a neupravené.
DROP POLICY IF EXISTS messages_send ON messages;
CREATE POLICY messages_send ON messages FOR INSERT TO rejnox_app
  WITH CHECK (
    sender_id = app_user_id()
    AND kind IN ('text', 'image')
    AND deleted_at IS NULL AND edited_at IS NULL
    AND can_send_message(conversation_id)
    AND (reply_to IS NULL OR message_in_conversation(reply_to, conversation_id))
  );

ALTER TABLE message_images ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS message_images_read ON message_images;
CREATE POLICY message_images_read ON message_images FOR SELECT TO rejnox_app
  USING (EXISTS (SELECT 1 FROM messages m WHERE m.id = message_id AND m.deleted_at IS NULL));
DROP POLICY IF EXISTS message_images_insert ON message_images;
CREATE POLICY message_images_insert ON message_images FOR INSERT TO rejnox_app
  WITH CHECK (EXISTS (
    SELECT 1 FROM messages m
    WHERE m.id = message_id AND m.sender_id = app_user_id() AND m.kind = 'image' AND m.deleted_at IS NULL
  ));

ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS message_reactions_read ON message_reactions;
CREATE POLICY message_reactions_read ON message_reactions FOR SELECT TO rejnox_app
  USING (EXISTS (SELECT 1 FROM messages m WHERE m.id = message_id));

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_blocks_own ON user_blocks;
CREATE POLICY user_blocks_own ON user_blocks TO rejnox_app
  USING (blocker_id = app_user_id()) WITH CHECK (blocker_id = app_user_id());

-- ------------------------------------------------------------------ práva

REVOKE ALL ON FUNCTION member_joined_at(uuid), is_group_admin(uuid), is_blocked_between(uuid, uuid),
  chat_can_contact(uuid), chat_contacts(), can_send_message(uuid), message_in_conversation(uuid, uuid),
  chat_system_message(uuid, text), touch_conversation(), start_direct(uuid), chat_group_max(),
  chat_clean_title(text), chat_add_members(uuid, uuid[]), create_group(text, uuid[]),
  add_group_members(uuid, uuid[]), remove_group_member(uuid, uuid), set_group_role(uuid, uuid, text),
  rename_group(uuid, text), set_group_invite(uuid, text), join_group_by_code(text), delete_group(uuid),
  edit_message(uuid, text), delete_message(uuid), react_message(uuid, text), set_typing(uuid),
  set_conversation_muted(uuid, boolean), mark_conversation_read(uuid, timestamptz)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION member_joined_at(uuid), is_group_admin(uuid), chat_can_contact(uuid),
  chat_contacts(), can_send_message(uuid), message_in_conversation(uuid, uuid), start_direct(uuid),
  create_group(text, uuid[]), add_group_members(uuid, uuid[]), remove_group_member(uuid, uuid),
  set_group_role(uuid, uuid, text), rename_group(uuid, text), set_group_invite(uuid, text),
  join_group_by_code(text), delete_group(uuid), edit_message(uuid, text), delete_message(uuid),
  react_message(uuid, text), set_typing(uuid), set_conversation_muted(uuid, boolean),
  mark_conversation_read(uuid, timestamptz)
  TO rejnox_app;

GRANT SELECT, INSERT ON message_images TO rejnox_app;
GRANT SELECT ON message_reactions TO rejnox_app;
GRANT SELECT, INSERT, DELETE ON user_blocks TO rejnox_app;
