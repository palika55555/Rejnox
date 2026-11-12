-- Overenie prístupových pravidiel. Spúšťa sa ako rola rejnox_app (scripts/db_test.sh).
-- Všetko beží v transakcii, ktorá sa na konci zahodí.
BEGIN;

DO $$
DECLARE
  t uuid := gen_random_uuid();   -- tréner
  a uuid := gen_random_uuid();   -- klient A
  b uuid := gen_random_uuid();   -- cudzí používateľ B
  tc uuid := gen_random_uuid();
  ex uuid := gen_random_uuid();
  w uuid := gen_random_uuid();
  conv uuid;
  n int;
BEGIN
  INSERT INTO users (id, email, password_hash, display_name, role) VALUES
    (t, 't@test.local', 'x', 'Tréner', 'trainer'),
    (a, 'a@test.local', 'x', 'Klient A', 'member'),
    (b, 'b@test.local', 'x', 'Cudzí B', 'member');

  -- 1. Bez prihlásenia nevidno nič.
  SELECT count(*) INTO n FROM users;
  ASSERT n = 0, 'neprihlásený vidí používateľov';
  SELECT count(*) INTO n FROM gyms;
  ASSERT n = 0, 'neprihlásený vidí fitká';

  -- 2. Tréner vidí len svoj účet a založí klienta s pozvánkou.
  PERFORM set_config('app.user_id', t::text, true);
  SELECT count(*) INTO n FROM users;
  ASSERT n = 1, 'tréner vidí cudzie účty';

  BEGIN
    INSERT INTO trainer_clients (trainer_id, client_user_id, client_name, status)
    VALUES (t, b, 'Ukradnutý', 'linked');
    RAISE EXCEPTION 'FAIL: tréner si sám priradil cudzí účet';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  INSERT INTO trainer_clients (id, trainer_id, client_name, status, invite_token_hash, invite_expires_at)
  VALUES (tc, t, 'Klient A', 'invited', 'hash-123', now() + interval '1 day');
  INSERT INTO exercises (id, name, created_by) VALUES (ex, 'Testovací drep', t);
  INSERT INTO workouts (id, trainer_client_id, title, created_by) VALUES (w, tc, 'Nohy', t);
  INSERT INTO workout_exercises (workout_id, exercise_id, position, sets, reps, weight_kg)
  VALUES (w, ex, 0, 4, 6, 120);
  INSERT INTO set_logs (trainer_client_id, exercise_id, reps, weight_kg, logged_by)
  VALUES (tc, ex, 6, 120, t);

  -- 3. Dva termíny trénera sa nesmú prekrývať.
  INSERT INTO bookings (trainer_id, trainer_client_id, during)
  VALUES (t, tc, tstzrange('2030-01-01 10:00+00', '2030-01-01 11:00+00'));
  BEGIN
    INSERT INTO bookings (trainer_id, trainer_client_id, during)
    VALUES (t, tc, tstzrange('2030-01-01 10:30+00', '2030-01-01 11:30+00'));
    RAISE EXCEPTION 'FAIL: prekrývajúce sa termíny prešli';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;

  -- 4. Klient A pred prijatím pozvánky nevidí nič, po prijatí vidí svoju históriu.
  PERFORM set_config('app.user_id', a::text, true);
  SELECT count(*) INTO n FROM workouts;
  ASSERT n = 0, 'neprepojený klient vidí tréningy';
  PERFORM accept_client_invite('hash-123');
  SELECT count(*) INTO n FROM workouts;
  ASSERT n = 1, 'klient nevidí svoj tréning';
  SELECT count(*) INTO n FROM workout_exercises;
  ASSERT n = 1, 'klient nevidí cviky';
  SELECT count(*) INTO n FROM set_logs;
  ASSERT n = 1, 'klient nevidí svoje série';
  INSERT INTO member_passes (user_id, label, code) VALUES (a, 'Gym Fit', '123456');
  conv := start_conversation(t);
  INSERT INTO messages (conversation_id, sender_id, body) VALUES (conv, a, 'Ahoj');

  -- 5. Cudzí používateľ B nevidí nič z toho a nevie sa nikam dostať.
  PERFORM set_config('app.user_id', b::text, true);
  SELECT count(*) INTO n FROM trainer_clients;
  ASSERT n = 0, 'B vidí cudzie prepojenie';
  SELECT count(*) INTO n FROM workouts;
  ASSERT n = 0, 'B vidí cudzie tréningy';
  SELECT count(*) INTO n FROM workout_exercises;
  ASSERT n = 0, 'B vidí cudzie cviky';
  SELECT count(*) INTO n FROM set_logs;
  ASSERT n = 0, 'B vidí cudzie série';
  SELECT count(*) INTO n FROM bookings;
  ASSERT n = 0, 'B vidí cudzie rezervácie';
  SELECT count(*) INTO n FROM member_passes;
  ASSERT n = 0, 'B vidí cudziu permanentku';
  SELECT count(*) INTO n FROM messages;
  ASSERT n = 0, 'B číta cudzie správy';
  SELECT count(*) INTO n FROM leaderboard;
  ASSERT n = 0, 'v rebríčku je niekto, kto si ho nezapol';

  BEGIN
    INSERT INTO workouts (trainer_client_id, title) VALUES (tc, 'hack');
    RAISE EXCEPTION 'FAIL: B zapísal tréning cudziemu klientovi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO messages (conversation_id, sender_id, body) VALUES (conv, b, 'hack');
    RAISE EXCEPTION 'FAIL: B napísal do cudzej konverzácie';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO conversation_members (conversation_id, user_id) VALUES (conv, b);
    RAISE EXCEPTION 'FAIL: B sa pridal do cudzej konverzácie';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO messages (conversation_id, sender_id, body) VALUES (conv, a, 'falošná');
    RAISE EXCEPTION 'FAIL: B poslal správu v cudzom mene';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- 6. Tréner číta správu od klienta.
  PERFORM set_config('app.user_id', t::text, true);
  SELECT count(*) INTO n FROM messages;
  ASSERT n = 1, 'tréner nevidí správu klienta';

  -- 7. Klient ukončí spoluprácu: tréner stratí prístup a nevie si ho vrátiť.
  PERFORM set_config('app.user_id', a::text, true);
  BEGIN
    UPDATE trainer_clients SET client_name = 'Prepísané' WHERE id = tc;
    RAISE EXCEPTION 'FAIL: klient zmenil trénerov záznam';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE trainer_clients SET status = 'ended' WHERE id = tc;
  UPDATE users SET leaderboard_opt_in = true WHERE id = a;

  PERFORM set_config('app.user_id', t::text, true);
  SELECT count(*) INTO n FROM workouts;
  ASSERT n = 0, 'tréner vidí tréningy po ukončení';
  SELECT count(*) INTO n FROM set_logs;
  ASSERT n = 0, 'tréner vidí série po ukončení';
  BEGIN
    UPDATE trainer_clients SET status = 'linked' WHERE id = tc;
    RAISE EXCEPTION 'FAIL: tréner obnovil ukončenú spoluprácu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- 8. Klient má históriu stále a po zapnutí je v rebríčku.
  PERFORM set_config('app.user_id', a::text, true);
  SELECT count(*) INTO n FROM workouts;
  ASSERT n = 1, 'klient prišiel o históriu';
  PERFORM set_config('app.user_id', b::text, true);
  SELECT count(*) INTO n FROM leaderboard WHERE user_id = a AND best_kg = 120;
  ASSERT n = 1, 'klient so zapnutým rebríčkom v ňom chýba';

  RAISE NOTICE 'VŠETKY KONTROLY PREŠLI';
END
$$;

ROLLBACK;
