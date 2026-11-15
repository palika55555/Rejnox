-- Rejnox: kalendár trénera.
-- 1) Tréner vypisuje voľné termíny (trainer_slots) s počtom miest; prepojený
--    klient si v nich miesto rezervuje sám, bez čakania na potvrdenie.
-- 2) Mimo vypísaných termínov klient o tréning požiada (rezervácia "requested"),
--    tréner ju potvrdí alebo odmietne. Tréner vie klientovi termín aj priamo
--    zapísať (rovno potvrdený), voliteľne s plánom tréningu.
-- 3) Klient vidí kalendár svojho trénera len cez funkciu trainer_schedule:
--    termíny s obsadenosťou a obsadené časy bez mien ostatných klientov.

-- ------------------------------------------------------------ voľné termíny

CREATE TABLE trainer_slots (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  during     tstzrange NOT NULL CHECK (NOT isempty(during)),
  capacity   integer NOT NULL DEFAULT 1 CHECK (capacity BETWEEN 1 AND 50),
  title      text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  note       text CHECK (char_length(note) <= 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  -- Vypísané termíny jedného trénera sa neprekrývajú.
  EXCLUDE USING gist (trainer_id WITH =, during WITH &&)
);
CREATE INDEX trainer_slots_time_idx ON trainer_slots USING gist (trainer_id, during);

-- ------------------------------------------------------------- rezervácie

ALTER TABLE bookings
  ADD COLUMN slot_id    uuid REFERENCES trainer_slots (id) ON DELETE SET NULL,
  ADD COLUMN workout_id uuid REFERENCES workouts (id) ON DELETE SET NULL,
  ADD COLUMN title      text CHECK (char_length(title) BETWEEN 1 AND 80),
  ADD COLUMN note       text CHECK (char_length(note) <= 500),
  ADD COLUMN created_by uuid REFERENCES users (id) ON DELETE SET NULL;

-- Kolíziu hlídajú len potvrdené osobné tréningy. Žiadosti sa smú prekrývať
-- (tréner si vyberie), miesta v jednom termíne zdieľa viac klientov.
ALTER TABLE bookings DROP CONSTRAINT bookings_trainer_id_during_excl;
ALTER TABLE bookings ADD CONSTRAINT bookings_confirmed_no_overlap
  EXCLUDE USING gist (trainer_id WITH =, during WITH &&)
  WHERE (status = 'confirmed' AND slot_id IS NULL);

-- Jeden klient má v termíne najviac jedno miesto.
CREATE UNIQUE INDEX bookings_one_seat_per_client
  ON bookings (slot_id, trainer_client_id)
  WHERE slot_id IS NOT NULL AND status <> 'cancelled';

CREATE INDEX bookings_trainer_time_idx ON bookings USING gist (trainer_id, during);
CREATE INDEX bookings_client_idx ON bookings (trainer_client_id);

-- ---------------------------------------------------------------- pomocné

-- Je prihlásený prepojeným klientom tohto trénera?
CREATE FUNCTION is_linked_client_of(p_trainer uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trainer_clients t
    WHERE t.trainer_id = p_trainer
      AND t.client_user_id = app_user_id()
      AND t.status = 'linked'
  )
$$;

-- Zápisy do kalendára jedného trénera idú za sebou (kontroly kapacity a kolízií).
CREATE FUNCTION lock_trainer_calendar(p_trainer uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT pg_advisory_xact_lock(hashtextextended('trainer_calendar:' || p_trainer::text, 0))
$$;

-- -------------------------------------------------- pravidlá pre termíny

CREATE FUNCTION trainer_slots_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  taken integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.trainer_id AND role = 'trainer') THEN
    RAISE EXCEPTION 'only trainers can publish slots' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.trainer_id <> OLD.trainer_id THEN
    RAISE EXCEPTION 'slot owner cannot change' USING ERRCODE = 'insufficient_privilege';
  END IF;

  PERFORM lock_trainer_calendar(NEW.trainer_id);

  IF EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.trainer_id = NEW.trainer_id AND b.slot_id IS NULL
      AND b.status = 'confirmed' AND b.during && NEW.during
  ) THEN
    RAISE EXCEPTION 'time unavailable' USING ERRCODE = 'exclusion_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    SELECT count(*) INTO taken FROM bookings
    WHERE slot_id = NEW.id AND status <> 'cancelled';
    IF taken > NEW.capacity THEN
      RAISE EXCEPTION 'capacity below booked seats' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trainer_slots_guard
BEFORE INSERT OR UPDATE ON trainer_slots
FOR EACH ROW EXECUTE FUNCTION trainer_slots_guard();

-- Rezervácie v termíne nasledujú jeho čas.
CREATE FUNCTION trainer_slots_follow() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.during <> OLD.during THEN
    UPDATE bookings SET during = NEW.during WHERE slot_id = NEW.id;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER trainer_slots_follow
AFTER UPDATE ON trainer_slots
FOR EACH ROW EXECUTE FUNCTION trainer_slots_follow();

ALTER TABLE trainer_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY trainer_slots_own ON trainer_slots TO rejnox_app
  USING (trainer_id = app_user_id())
  WITH CHECK (trainer_id = app_user_id());

-- ---------------------------------------------- pravidlá pre rezervácie

-- Kto čo smie (nahrádza verziu zo 007).
CREATE OR REPLACE FUNCTION bookings_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
  me uuid := app_user_id();
BEGIN
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;

  IF link.trainer_id IS DISTINCT FROM NEW.trainer_id THEN
    RAISE EXCEPTION 'booking trainer does not match client link'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_by := me;
  ELSIF NEW.trainer_id <> OLD.trainer_id
     OR NEW.trainer_client_id <> OLD.trainer_client_id
     OR NEW.created_at <> OLD.created_at
     OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'booking owner cannot change' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Tréner smie všetko ostatné. Termín sa po odstránení (ON DELETE SET NULL)
  -- odpojí len od zrušených rezervácií, o to sa stará API.
  IF me IS NOT DISTINCT FROM NEW.trainer_id THEN
    RETURN NEW;
  END IF;

  -- Plán k tréningu pripája len tréner.
  IF (TG_OP = 'INSERT' AND NEW.workout_id IS NOT NULL)
     OR (TG_OP = 'UPDATE' AND NEW.workout_id IS DISTINCT FROM OLD.workout_id) THEN
    RAISE EXCEPTION 'only the trainer can attach a plan'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Zrušiť vlastný termín smie klient vždy (aj po ukončení spolupráce).
  IF TG_OP = 'UPDATE' AND NEW.status = 'cancelled' AND OLD.status <> 'cancelled'
     AND NEW.during = OLD.during AND NEW.slot_id IS NOT DISTINCT FROM OLD.slot_id
     AND link.client_user_id = me THEN
    RETURN NEW;
  END IF;

  -- Všetko ostatné len pri aktívnej spolupráci.
  IF link.status <> 'linked' OR link.client_user_id IS DISTINCT FROM me THEN
    RAISE EXCEPTION 'no active link with this trainer'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Miesto vo vypísanom termíne je hneď potvrdené (kapacitu stráži
    -- bookings_schedule_guard), ostatné je len žiadosť.
    IF NOT (NEW.status = 'requested' AND NEW.slot_id IS NULL)
       AND NOT (NEW.status = 'confirmed' AND NEW.slot_id IS NOT NULL) THEN
      RAISE EXCEPTION 'client can only request a booking'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;

  -- Úprava žiadosti, ktorú tréner ešte nepotvrdil.
  IF OLD.status = 'requested' AND NEW.status = 'requested'
     AND OLD.slot_id IS NULL AND NEW.slot_id IS NULL THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'client can only cancel or edit a pending request'
    USING ERRCODE = 'insufficient_privilege';
END
$$;

-- Kapacita termínov a voľný čas. Beží po bookings_guard (abecedne).
CREATE FUNCTION bookings_schedule_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  slot trainer_slots%ROWTYPE;
  taken integer;
  by_trainer boolean := app_user_id() IS NOT DISTINCT FROM NEW.trainer_id;
BEGIN
  IF NEW.status = 'cancelled' THEN
    RETURN NEW;
  END IF;
  -- Nič sa nemení na čase ani obsadenosti (napr. tréner pripojil plán).
  IF TG_OP = 'UPDATE' AND NEW.status = OLD.status AND NEW.during = OLD.during
     AND NEW.slot_id IS NOT DISTINCT FROM OLD.slot_id THEN
    RETURN NEW;
  END IF;

  PERFORM lock_trainer_calendar(NEW.trainer_id);

  IF NEW.slot_id IS NOT NULL THEN
    SELECT * INTO slot FROM trainer_slots WHERE id = NEW.slot_id;
    IF slot.id IS NULL OR slot.trainer_id <> NEW.trainer_id THEN
      RAISE EXCEPTION 'slot not found' USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.during := slot.during;
    IF NOT by_trainer AND lower(slot.during) <= now() THEN
      RAISE EXCEPTION 'slot in past' USING ERRCODE = 'check_violation';
    END IF;
    SELECT count(*) INTO taken FROM bookings
    WHERE slot_id = NEW.slot_id AND status <> 'cancelled' AND id <> NEW.id;
    IF taken >= slot.capacity THEN
      RAISE EXCEPTION 'slot full' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;

  IF NOT by_trainer AND lower(NEW.during) <= now() THEN
    RAISE EXCEPTION 'time in past' USING ERRCODE = 'check_violation';
  END IF;

  -- Osobný tréning sa nesmie prekrývať s vypísaným termínom.
  IF EXISTS (
    SELECT 1 FROM trainer_slots s
    WHERE s.trainer_id = NEW.trainer_id AND s.during && NEW.during
  ) THEN
    RAISE EXCEPTION 'time unavailable' USING ERRCODE = 'exclusion_violation';
  END IF;

  -- Žiadosť o čas, ktorý je už obsadený, nemá zmysel.
  IF NEW.status = 'requested' AND EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.trainer_id = NEW.trainer_id AND b.slot_id IS NULL
      AND b.status = 'confirmed' AND b.during && NEW.during AND b.id <> NEW.id
  ) THEN
    RAISE EXCEPTION 'time unavailable' USING ERRCODE = 'exclusion_violation';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER bookings_schedule_guard
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION bookings_schedule_guard();

-- ------------------------------------------- kalendár trénera pre klienta

-- Termíny s obsadenosťou a obsadené časy (bez mien) na zvolené obdobie.
-- Vidí ho tréner a jeho prepojení klienti. Obdobie je najviac 62 dní.
CREATE FUNCTION trainer_schedule(p_trainer uuid, p_from timestamptz, p_to timestamptz)
RETURNS TABLE (
  kind      text,
  slot_id   uuid,
  starts_at timestamptz,
  ends_at   timestamptz,
  title     text,
  note      text,
  capacity  integer,
  taken     integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF app_user_id() IS DISTINCT FROM p_trainer AND NOT is_linked_client_of(p_trainer) THEN
    RAISE EXCEPTION 'no active link with this trainer' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_to <= p_from OR p_to - p_from > interval '62 days' THEN
    RAISE EXCEPTION 'invalid range' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  RETURN QUERY
  SELECT 'slot'::text, s.id, lower(s.during), upper(s.during), s.title, s.note, s.capacity,
         (SELECT count(*)::integer FROM bookings b
          WHERE b.slot_id = s.id AND b.status <> 'cancelled')
  FROM trainer_slots s
  WHERE s.trainer_id = p_trainer AND s.during && tstzrange(p_from, p_to)
  UNION ALL
  SELECT 'busy'::text, NULL::uuid, lower(b.during), upper(b.during), NULL::text, NULL::text,
         NULL::integer, NULL::integer
  FROM bookings b
  WHERE b.trainer_id = p_trainer AND b.slot_id IS NULL AND b.status = 'confirmed'
    AND b.during && tstzrange(p_from, p_to)
  ORDER BY 3;
END
$$;

REVOKE ALL ON FUNCTION is_linked_client_of(uuid), lock_trainer_calendar(uuid),
  trainer_slots_guard(), trainer_slots_follow(), bookings_schedule_guard(),
  trainer_schedule(uuid, timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_linked_client_of(uuid),
  trainer_schedule(uuid, timestamptz, timestamptz) TO rejnox_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON trainer_slots TO rejnox_app;
