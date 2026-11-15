-- Rejnox: spresnenie chatu po revízii.
-- 1) Staré start_conversation zakladalo konverzáciu s kýmkoľvek (bez prepojenia
--    tréner–klient). Appka ho nepoužíva, chat ide len cez link_conversation.
-- 2) Prečítané sa posúva len po čas správ, ktoré appka naozaj dostala,
--    nie po now() (začiatok transakcie), ktoré by „prečítalo“ aj nevidené.
-- 3) Čas správy = skutočný čas zápisu (clock_timestamp), nie začiatok
--    transakcie, aby priebežné načítanie (?after=) nepreskočilo správu.

REVOKE EXECUTE ON FUNCTION start_conversation(uuid) FROM rejnox_app;

ALTER TABLE messages ALTER COLUMN sent_at SET DEFAULT clock_timestamp();

DROP FUNCTION mark_conversation_read(uuid);

CREATE FUNCTION mark_conversation_read(conv_id uuid, up_to timestamptz) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  UPDATE conversation_members SET last_read_at = greatest(last_read_at, up_to)
  WHERE conversation_id = conv_id AND user_id = app_user_id() AND up_to IS NOT NULL
$$;

REVOKE ALL ON FUNCTION mark_conversation_read(uuid, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mark_conversation_read(uuid, timestamptz) TO rejnox_app;
