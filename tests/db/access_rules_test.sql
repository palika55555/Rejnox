-- Overenie prístupových pravidiel. Spúšťa sa ako rola rejnox_app (scripts/db_test.sh).
-- Všetko beží v transakcii, ktorá sa na konci zahodí.
BEGIN;

DO $$
DECLARE
  t uuid := gen_random_uuid();   -- tréner
  a uuid := gen_random_uuid();   -- klient A
  b uuid := gen_random_uuid();   -- cudzí používateľ B
  x uuid := gen_random_uuid();   -- iný tréner X
  tc uuid := gen_random_uuid();
  ex uuid := gen_random_uuid();
  w uuid := gen_random_uuid();
  conv uuid;
  n int;
BEGIN
  INSERT INTO users (id, email, password_hash, display_name, role) VALUES
    (t, 't@test.local', 'x', 'Tréner', 'trainer'),
    (a, 'a@test.local', 'x', 'Klient A', 'member'),
    (b, 'b@test.local', 'x', 'Cudzí B', 'member'),
    (x, 'x@test.local', 'x', 'Tréner X', 'trainer');

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

  -- 4a. Plány a série od trénera klient len číta.
  UPDATE workouts SET title = 'prepísané' WHERE id = w;
  DELETE FROM set_logs WHERE trainer_client_id = tc;
  DELETE FROM workout_exercises WHERE workout_id = w;
  SELECT count(*) INTO n FROM workouts WHERE title = 'Nohy';
  ASSERT n = 1, 'klient prepísal plán od trénera';
  SELECT count(*) INTO n FROM set_logs WHERE trainer_client_id = tc;
  ASSERT n = 1, 'klient zmazal série od trénera';
  SELECT count(*) INTO n FROM workout_exercises WHERE workout_id = w;
  ASSERT n = 1, 'klient zmazal cviky z plánu';
  BEGIN
    INSERT INTO workouts (trainer_client_id, title) VALUES (tc, 'od klienta');
    RAISE EXCEPTION 'FAIL: klient zapísal plán za trénera';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO trainer_clients (trainer_id, client_name) VALUES (a, 'Nie som tréner');
    RAISE EXCEPTION 'FAIL: člen si pridal klienta';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Vlastný záznam nesmie niesť ID spolupráce (inak by sa "prilepil"
  -- k cudzej spolupráci). Chráni to obmedzenie num_nonnulls v tabuľkách.
  BEGIN
    INSERT INTO set_logs (user_id, trainer_client_id, exercise_id, reps, weight_kg)
    VALUES (a, tc, ex, 1, 1);
    RAISE EXCEPTION 'FAIL: séria s vlastníkom aj spoluprácou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO workouts (user_id, trainer_client_id, title) VALUES (a, tc, 'x');
    RAISE EXCEPTION 'FAIL: plán s vlastníkom aj spoluprácou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- Vlastný tréning si klient spravuje sám.
  INSERT INTO workouts (user_id, title) VALUES (a, 'Môj tréning');
  DELETE FROM workouts WHERE user_id = a;

  INSERT INTO member_passes (user_id, label, code) VALUES (a, 'Gym Fit', '123456');
  conv := start_conversation(t);
  INSERT INTO messages (conversation_id, sender_id, body) VALUES (conv, a, 'Ahoj');

  -- 4b. Klient si žiada termín: len u svojho trénera a potvrdiť si ho nevie sám.
  BEGIN
    INSERT INTO bookings (trainer_id, trainer_client_id, during)
    VALUES (x, tc, tstzrange('2030-02-01 10:00+00', '2030-02-01 11:00+00'));
    RAISE EXCEPTION 'FAIL: klient založil termín cudziemu trénerovi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO bookings (trainer_id, trainer_client_id, during, status)
    VALUES (t, tc, tstzrange('2030-02-01 10:00+00', '2030-02-01 11:00+00'), 'confirmed');
    RAISE EXCEPTION 'FAIL: klient si sám potvrdil termín';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  INSERT INTO bookings (trainer_id, trainer_client_id, during)
  VALUES (t, tc, tstzrange('2030-02-01 10:00+00', '2030-02-01 11:00+00'));
  BEGIN
    UPDATE bookings SET status = 'confirmed' WHERE trainer_client_id = tc;
    RAISE EXCEPTION 'FAIL: klient potvrdil termín úpravou';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- 4c. Tréner nevie prepojeného klienta znova pozvať ani mu zmazať históriu.
  PERFORM set_config('app.user_id', t::text, true);
  BEGIN
    UPDATE trainer_clients
    SET status = 'invited', invite_token_hash = 'hash-unos',
        invite_expires_at = now() + interval '1 day'
    WHERE id = tc;
    RAISE EXCEPTION 'FAIL: tréner znova pozval prepojeného klienta';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  DELETE FROM trainer_clients WHERE id = tc;
  SELECT count(*) INTO n FROM trainer_clients WHERE id = tc;
  ASSERT n = 1, 'tréner zmazal prepojeného klienta aj s históriou';
  UPDATE bookings SET status = 'confirmed' WHERE trainer_client_id = tc
    AND during = tstzrange('2030-02-01 10:00+00', '2030-02-01 11:00+00');
  SELECT count(*) INTO n FROM bookings WHERE status = 'confirmed';
  ASSERT n = 1, 'tréner nevie potvrdiť termín';
  PERFORM set_config('app.user_id', a::text, true);

  -- 4d. Klient nevie presunúť potvrdený termín, len ho zrušiť.
  BEGIN
    UPDATE bookings
    SET during = tstzrange('2030-03-01 10:00+00', '2030-03-01 11:00+00')
    WHERE status = 'confirmed';
    RAISE EXCEPTION 'FAIL: klient presunul potvrdený termín';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE bookings
    SET status = 'cancelled',
        during = tstzrange('2030-03-01 10:00+00', '2030-03-01 11:00+00')
    WHERE status = 'confirmed';
    RAISE EXCEPTION 'FAIL: klient pri zrušení zmenil čas';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Nepotvrdenú žiadosť si posunúť môže.
  UPDATE bookings
  SET during = tstzrange('2030-01-02 10:00+00', '2030-01-02 11:00+00')
  WHERE status = 'requested';
  UPDATE bookings SET status = 'cancelled' WHERE status = 'confirmed';
  SELECT count(*) INTO n FROM bookings WHERE status = 'cancelled';
  ASSERT n = 1, 'klient nevie zrušiť termín';
  BEGIN
    UPDATE bookings SET status = 'requested' WHERE status = 'cancelled';
    RAISE EXCEPTION 'FAIL: klient obnovil zrušený termín';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Mazať termíny smie len tréner.
  SELECT count(*) INTO n FROM bookings WHERE trainer_client_id = tc;
  ASSERT n = 2, 'nečakaný počet termínov pred pokusom o zmazanie';
  DELETE FROM bookings WHERE trainer_client_id = tc;
  SELECT count(*) INTO n FROM bookings WHERE trainer_client_id = tc;
  ASSERT n = 2, 'klient zmazal termíny';

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
    INSERT INTO set_logs (trainer_client_id, exercise_id, reps, weight_kg, logged_by)
    VALUES (tc, ex, 1, 999, t);
    RAISE EXCEPTION 'FAIL: tréner zapisuje klientovi po ukončení';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE trainer_clients SET status = 'linked' WHERE id = tc;
    RAISE EXCEPTION 'FAIL: tréner obnovil ukončenú spoluprácu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- 7b. Po ukončení klient nové termíny nežiada, ale svoje zrušiť môže.
  PERFORM set_config('app.user_id', a::text, true);
  BEGIN
    INSERT INTO bookings (trainer_id, trainer_client_id, during)
    VALUES (t, tc, tstzrange('2030-04-01 10:00+00', '2030-04-01 11:00+00'));
    RAISE EXCEPTION 'FAIL: klient po ukončení blokuje trénerovi kalendár';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE bookings
    SET during = tstzrange('2030-04-02 10:00+00', '2030-04-02 11:00+00')
    WHERE status = 'requested';
    RAISE EXCEPTION 'FAIL: klient po ukončení presúva žiadosti';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE bookings SET status = 'cancelled' WHERE status = 'requested';
  SELECT count(*) INTO n FROM bookings WHERE status = 'requested';
  ASSERT n = 0, 'klient po ukončení nevie zrušiť svoje žiadosti';

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
