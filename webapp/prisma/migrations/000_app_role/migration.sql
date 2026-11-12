-- Rejnox: rola, pod ktorou sa pripája aplikácia (Next.js API).
-- Platia na ňu pravidlá Row Level Security z ďalších migrácií.
-- Heslo sa v migrácii nenastavuje. Raz ho nastav ručne (Supabase → SQL editor):
--   ALTER ROLE rejnox_app WITH PASSWORD '...';
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rejnox_app') THEN
    CREATE ROLE rejnox_app LOGIN NOINHERIT;
  END IF;
END
$$;
