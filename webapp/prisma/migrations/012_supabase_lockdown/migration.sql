-- Rejnox: Supabase automaticky sprístupní tabuľky v schéme public cez svoje
-- REST API (roly anon a authenticated). Rejnox ho nepoužíva, všetko ide cez
-- naše API ako rola rejnox_app. Bez tohto by sa cez verejný anon kľúč dalo
-- čítať napr. public_profiles alebo volať auth_find_user (vracia hash hesla).
-- Mimo Supabase (lokálne) tieto roly neexistujú a migrácia nič nerobí.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon')
     AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
    REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
    -- Aj pre tabuľky a funkcie z budúcich migrácií.
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;
  END IF;
END
$$;
