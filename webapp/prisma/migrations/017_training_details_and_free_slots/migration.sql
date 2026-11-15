-- Rejnox: rozpis rezervovaných tréningov a upozornenia na voľné termíny.
-- 1) Klient vidí svoje najbližšie tréningy u trénerov aj s názvom a poznámkou
--    termínu a s plánom (cviky), ktorý k tréningu tréner pripojil.
-- 2) Plán k tréningu tréner pripojí aj dodatočne → klient dostane upozornenie.
-- 3) Keď tréner vypíše termín alebo sa uvoľní miesto či čas, dostanú
--    upozornenie jeho prepojení klienti. Viac termínov za sebou sa zlúči
--    do jedného upozornenia, aby klientov nezahltili.

-- ------------------------------------------------- moje najbližšie tréningy

-- Rezervácie prihláseného klienta (u všetkých trénerov) v zvolenom období.
-- Termíny (trainer_slots) klient priamo čítať nesmie, preto SECURITY DEFINER.
CREATE FUNCTION my_trainings(p_from timestamptz, p_to timestamptz)
RETURNS TABLE (
  id           uuid,
  link_id      uuid,
  trainer_name text,
  starts_at    timestamptz,
  ends_at      timestamptz,
  status       text,
  in_slot      boolean,
  title        text,
  note         text,
  slot_note    text,
  workout      json
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_to <= p_from OR p_to - p_from > interval '62 days' THEN
    RAISE EXCEPTION 'invalid range' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  RETURN QUERY
  SELECT b.id, t.id, display_name_of(t.trainer_id), lower(b.during), upper(b.during),
         b.status::text, b.slot_id IS NOT NULL, coalesce(b.title, s.title), b.note, s.note,
         CASE WHEN w.id IS NULL THEN NULL ELSE json_build_object(
           'id', w.id::text,
           'title', w.title,
           'scheduledOn', to_char(w.scheduled_on, 'YYYY-MM-DD'),
           'trainerName', display_name_of(t.trainer_id),
           'exercises', coalesce((
             SELECT json_agg(json_build_object(
               'exerciseId', we.exercise_id, 'name', e.name,
               'muscleGroup', e.muscle_group, 'sets', we.sets, 'reps', we.reps,
               'weightKg', we.weight_kg::float8, 'note', we.note
             ) ORDER BY we.position)
             FROM workout_exercises we JOIN exercises e ON e.id = we.exercise_id
             WHERE we.workout_id = w.id
           ), '[]'::json)
         ) END
  FROM bookings b
  JOIN trainer_clients t ON t.id = b.trainer_client_id
  LEFT JOIN trainer_slots s ON s.id = b.slot_id
  LEFT JOIN workouts w ON w.id = b.workout_id
  WHERE t.client_user_id = app_user_id()
    AND b.status <> 'cancelled'
    AND b.during && tstzrange(p_from, p_to)
  ORDER BY lower(b.during)
  LIMIT 100;
END
$$;

-- ------------------------------------------------- plán pripojený k tréningu

CREATE FUNCTION notify_booking_plan() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
BEGIN
  IF NEW.workout_id IS NULL OR NEW.workout_id IS NOT DISTINCT FROM OLD.workout_id
     OR NEW.status = 'cancelled' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO link FROM trainer_clients WHERE id = NEW.trainer_client_id;
  PERFORM notify(link.client_user_id, 'training', 'Rozpis tréningu',
    display_name_of(NEW.trainer_id) || ' pripravil plán na tréning '
      || to_char(lower(NEW.during) AT TIME ZONE 'Europe/Bratislava', 'DD. MM. HH24:MI') || '.',
    link.id);
  RETURN NULL;
END
$$;

CREATE TRIGGER notify_booking_plan
AFTER UPDATE OF workout_id ON bookings
FOR EACH ROW EXECUTE FUNCTION notify_booking_plan();

-- ------------------------------------------------- voľné termíny → klienti

-- Upozorní prepojených klientov trénera (okrem p_skip a tých, čo už v termíne
-- p_slot majú miesto). Ak klient má od tohto trénera ešte neprečítané
-- upozornenie na voľné termíny z poslednej hodiny, zlúči sa s ním.
CREATE FUNCTION notify_free_time(p_trainer uuid, p_skip uuid, p_slot uuid, p_title text, p_body text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  link trainer_clients%ROWTYPE;
BEGIN
  FOR link IN
    SELECT * FROM trainer_clients t
    WHERE t.trainer_id = p_trainer AND t.status = 'linked'
      AND t.client_user_id IS NOT NULL
      AND t.id IS DISTINCT FROM p_skip
      AND NOT EXISTS (
        SELECT 1 FROM bookings b
        WHERE p_slot IS NOT NULL AND b.slot_id = p_slot
          AND b.trainer_client_id = t.id AND b.status <> 'cancelled'
      )
  LOOP
    UPDATE notifications
    SET title = 'Nové voľné termíny',
        body = left(display_name_of(p_trainer) || ' má viac voľných termínov. Pozri kalendár.', 300),
        created_at = now()
    WHERE user_id = link.client_user_id AND link_id = link.id AND kind = 'slot'
      AND read_at IS NULL AND created_at > now() - interval '1 hour';
    IF NOT FOUND THEN
      PERFORM notify(link.client_user_id, 'slot', p_title, p_body, link.id);
    END IF;
  END LOOP;
END
$$;

-- Nový vypísaný termín.
CREATE FUNCTION notify_slot_published() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF lower(NEW.during) <= now() THEN
    RETURN NULL;
  END IF;
  PERFORM notify_free_time(NEW.trainer_id, NULL, NEW.id, 'Nový voľný termín',
    display_name_of(NEW.trainer_id) || ' vypísal ' || NEW.title || ' '
      || to_char(lower(NEW.during) AT TIME ZONE 'Europe/Bratislava', 'DD. MM. HH24:MI')
      || ' (' || NEW.capacity || CASE WHEN NEW.capacity = 1 THEN ' miesto' WHEN NEW.capacity < 5 THEN ' miesta' ELSE ' miest' END
      || ').');
  RETURN NULL;
END
$$;

CREATE TRIGGER notify_slot_published
AFTER INSERT ON trainer_slots
FOR EACH ROW EXECUTE FUNCTION notify_slot_published();

-- Zrušený budúci tréning uvoľní miesto v termíne alebo čas trénera.
-- Beží až pri potvrdení transakcie: keď tréner ruší celý termín, jeho
-- rezervácie sa zrušia a termín zmizne, a vtedy niet čo ponúkať.
CREATE FUNCTION notify_time_freed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  slot trainer_slots%ROWTYPE;
  at text := to_char(lower(NEW.during) AT TIME ZONE 'Europe/Bratislava', 'DD. MM. HH24:MI');
BEGIN
  IF NEW.status <> 'cancelled' OR OLD.status = 'cancelled' OR lower(NEW.during) <= now() THEN
    RETURN NULL;
  END IF;

  IF NEW.slot_id IS NOT NULL THEN
    SELECT * INTO slot FROM trainer_slots WHERE id = NEW.slot_id;
    IF slot.id IS NULL THEN
      RETURN NULL;
    END IF;
    PERFORM notify_free_time(NEW.trainer_id, NEW.trainer_client_id, slot.id, 'Uvoľnilo sa miesto',
      display_name_of(NEW.trainer_id) || ': v termíne ' || slot.title || ' ' || at
        || ' je voľné miesto.');
  ELSIF OLD.status = 'confirmed' THEN
    -- Čas medzitým mohol obsadiť iný tréning.
    IF EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.trainer_id = NEW.trainer_id AND b.status = 'confirmed'
        AND b.slot_id IS NULL AND b.during && NEW.during
    ) THEN
      RETURN NULL;
    END IF;
    PERFORM notify_free_time(NEW.trainer_id, NEW.trainer_client_id, NULL, 'Tréner má voľný čas',
      display_name_of(NEW.trainer_id) || ' má voľno ' || at
        || '. Môžeš požiadať o tréning.');
  END IF;
  RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER notify_time_freed
AFTER UPDATE OF status ON bookings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION notify_time_freed();

-- ------------------------------------------------------------------ práva

REVOKE ALL ON FUNCTION my_trainings(timestamptz, timestamptz), notify_booking_plan(),
  notify_free_time(uuid, uuid, uuid, text, text), notify_slot_published(),
  notify_time_freed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION my_trainings(timestamptz, timestamptz) TO rejnox_app;
