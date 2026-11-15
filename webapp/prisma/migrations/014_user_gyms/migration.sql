-- Rejnox: fitká pridávajú používatelia appky – nové fitko, fotky a cenník.
-- Fitko a cenu môže upraviť alebo zmazať len ten, kto ich pridal (pravidlá
-- gyms_* a gym_prices_* z 002_security). Fotky sú v databáze, aby nebolo
-- treba ďalšie úložisko; appka ich pred nahratím zmenší.

-- Rozumné dĺžky aj pre staré stĺpce. NOT VALID: kontroluje len nové a
-- menené riadky, staré dáta zostanú, ako sú.
ALTER TABLE gyms
  ADD CONSTRAINT gyms_address_len CHECK (char_length(address) <= 200) NOT VALID,
  ADD CONSTRAINT gyms_city_len CHECK (char_length(city) <= 80) NOT VALID;

-- Kontrola webu z 010 mala {3,300}, čo Postgres neberie (najviac 255
-- opakovaní), takže každý zápis s webom padol. Dĺžka zvlášť.
ALTER TABLE gyms DROP CONSTRAINT gyms_website_check;
ALTER TABLE gyms ADD CONSTRAINT gyms_website_check
  CHECK (char_length(website) <= 300 AND website ~ '^https://\S{3,}$');

ALTER TABLE gym_prices
  ADD CONSTRAINT gym_prices_max CHECK (price_cents <= 10000000) NOT VALID,
  ADD CONSTRAINT gym_prices_period_len CHECK (char_length(period) <= 40) NOT VALID;
CREATE INDEX gym_prices_submitted_by_idx ON gym_prices (submitted_by);

CREATE TABLE gym_photos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id       uuid NOT NULL REFERENCES gyms (id) ON DELETE CASCADE,
  uploaded_by  uuid REFERENCES users (id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
  data         bytea NOT NULL CHECK (octet_length(data) BETWEEN 1 AND 1500000),
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX gym_photos_gym_idx ON gym_photos (gym_id, created_at);
CREATE INDEX gym_photos_uploaded_by_idx ON gym_photos (uploaded_by);

GRANT SELECT, INSERT, DELETE ON gym_photos TO rejnox_app;

ALTER TABLE gym_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY gym_photos_read ON gym_photos FOR SELECT TO rejnox_app
  USING (app_user_id() IS NOT NULL);
CREATE POLICY gym_photos_insert ON gym_photos FOR INSERT TO rejnox_app
  WITH CHECK (uploaded_by = app_user_id());
CREATE POLICY gym_photos_delete ON gym_photos FOR DELETE TO rejnox_app
  USING (uploaded_by = app_user_id());
