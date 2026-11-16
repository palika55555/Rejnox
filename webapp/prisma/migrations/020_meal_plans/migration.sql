-- Rejnox: jedálničky od trénera.
-- 1) Tréner zostaví klientovi jedálniček na týždeň (dni 0 = pondelok … 6 = nedeľa,
--    v každom dni jedlá s kalóriami a makroživinami). Kým ho neodošle, je to koncept
--    a klient ho nevidí.
-- 2) Odoslaním (sent_at) sa jedálniček objaví klientovi v appke a príde mu upozornenie.
-- 3) Klient si v appke odškrtáva zjedené jedlá (meal_item_checks), tréner z toho
--    vidí, ako sa jedálničku drží.

CREATE TABLE meal_plans (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_client_id uuid NOT NULL REFERENCES trainer_clients (id) ON DELETE CASCADE,
  title             text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  note              text CHECK (char_length(note) <= 1000),
  starts_on         date,
  kcal_target       integer CHECK (kcal_target BETWEEN 500 AND 10000),
  protein_g_target  integer CHECK (protein_g_target BETWEEN 0 AND 1000),
  carbs_g_target    integer CHECK (carbs_g_target BETWEEN 0 AND 2000),
  fat_g_target      integer CHECK (fat_g_target BETWEEN 0 AND 1000),
  sent_at           timestamptz,
  created_by        uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX meal_plans_client_idx ON meal_plans (trainer_client_id, created_at DESC);

CREATE TABLE meal_plan_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id uuid NOT NULL REFERENCES meal_plans (id) ON DELETE CASCADE,
  day          smallint NOT NULL CHECK (day BETWEEN 0 AND 6),
  position     smallint NOT NULL CHECK (position BETWEEN 0 AND 99),
  meal         text NOT NULL CHECK (char_length(meal) BETWEEN 1 AND 40),
  name         text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
  amount       text CHECK (char_length(amount) <= 60),
  kcal         integer NOT NULL CHECK (kcal BETWEEN 0 AND 5000),
  protein_g    numeric(5, 1) NOT NULL DEFAULT 0 CHECK (protein_g BETWEEN 0 AND 500),
  carbs_g      numeric(5, 1) NOT NULL DEFAULT 0 CHECK (carbs_g BETWEEN 0 AND 1000),
  fat_g        numeric(5, 1) NOT NULL DEFAULT 0 CHECK (fat_g BETWEEN 0 AND 500),
  note         text CHECK (char_length(note) <= 200)
);
CREATE INDEX meal_plan_items_plan_idx ON meal_plan_items (meal_plan_id, day, position);

-- Zjedené jedlo v konkrétny deň (odškrtáva klient).
CREATE TABLE meal_item_checks (
  item_id    uuid NOT NULL REFERENCES meal_plan_items (id) ON DELETE CASCADE,
  eaten_on   date NOT NULL,
  checked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (item_id, eaten_on)
);

-- ------------------------------------------------------------ prístup

-- Je prihlásený klientom tejto spolupráce (aj ukončenej, históriu vidí ďalej)?
CREATE FUNCTION is_client_of(tc_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trainer_clients t
    WHERE t.id = tc_id AND t.client_user_id = app_user_id()
  )
$$;

-- Smie klient odškrtávať jedlo? Len z odoslaného jedálnička pri aktívnej spolupráci.
CREATE FUNCTION can_check_meal(p_item uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM meal_plan_items i
    JOIN meal_plans p ON p.id = i.meal_plan_id
    JOIN trainer_clients t ON t.id = p.trainer_client_id
    WHERE i.id = p_item AND p.sent_at IS NOT NULL
      AND t.client_user_id = app_user_id() AND t.status = 'linked'
  )
$$;

REVOKE ALL ON FUNCTION is_client_of(uuid), can_check_meal(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_client_of(uuid), can_check_meal(uuid) TO rejnox_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON meal_plans, meal_plan_items TO rejnox_app;
GRANT SELECT, INSERT, DELETE ON meal_item_checks TO rejnox_app;

ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_item_checks ENABLE ROW LEVEL SECURITY;

-- Tréner vidí a mení svoje jedálničky (kým spolupráca trvá), klient len odoslané.
CREATE POLICY meal_plans_read ON meal_plans FOR SELECT TO rejnox_app
  USING (is_active_trainer_of(trainer_client_id)
         OR (sent_at IS NOT NULL AND is_client_of(trainer_client_id)));
CREATE POLICY meal_plans_insert ON meal_plans FOR INSERT TO rejnox_app
  WITH CHECK (is_active_trainer_of(trainer_client_id));
CREATE POLICY meal_plans_update ON meal_plans FOR UPDATE TO rejnox_app
  USING (is_active_trainer_of(trainer_client_id))
  WITH CHECK (is_active_trainer_of(trainer_client_id));
CREATE POLICY meal_plans_delete ON meal_plans FOR DELETE TO rejnox_app
  USING (is_active_trainer_of(trainer_client_id));

-- Položky: čítať ich smie, kto vidí jedálniček; meniť, kto smie meniť jedálniček.
CREATE POLICY meal_plan_items_read ON meal_plan_items FOR SELECT TO rejnox_app
  USING (EXISTS (SELECT 1 FROM meal_plans p WHERE p.id = meal_plan_id));
CREATE POLICY meal_plan_items_write ON meal_plan_items TO rejnox_app
  USING (EXISTS (
    SELECT 1 FROM meal_plans p WHERE p.id = meal_plan_id AND is_active_trainer_of(p.trainer_client_id)))
  WITH CHECK (EXISTS (
    SELECT 1 FROM meal_plans p WHERE p.id = meal_plan_id AND is_active_trainer_of(p.trainer_client_id)));

-- Odškrtnutia: vidí ich tréner aj klient, zapisuje a maže len klient.
CREATE POLICY meal_item_checks_read ON meal_item_checks FOR SELECT TO rejnox_app
  USING (EXISTS (SELECT 1 FROM meal_plan_items i WHERE i.id = item_id));
CREATE POLICY meal_item_checks_insert ON meal_item_checks FOR INSERT TO rejnox_app
  WITH CHECK (can_check_meal(item_id));
CREATE POLICY meal_item_checks_delete ON meal_item_checks FOR DELETE TO rejnox_app
  USING (can_check_meal(item_id));

-- ------------------------------------------------------------ upozornenie

-- Odoslaný (aj znova odoslaný) jedálniček → klient.
CREATE FUNCTION notify_meal_plan_sent() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
BEGIN
  IF NEW.sent_at IS NULL OR NEW.sent_at IS NOT DISTINCT FROM OLD.sent_at THEN
    RETURN NULL;
  END IF;
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;
  PERFORM notify(link.client_user_id, 'meal_plan', 'Nový jedálniček od trénera',
    display_name_of(link.trainer_id) || ': ' || NEW.title, link.id);
  RETURN NULL;
END
$$;

REVOKE ALL ON FUNCTION notify_meal_plan_sent() FROM PUBLIC;

CREATE TRIGGER notify_meal_plan_sent
AFTER UPDATE OF sent_at ON meal_plans
FOR EACH ROW EXECUTE FUNCTION notify_meal_plan_sent();
