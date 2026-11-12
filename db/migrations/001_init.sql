-- Rejnox: základná schéma.
-- Spúšťa sa ako správca (postgres). Appka sa pripája ako rola rejnox_app,
-- na ktorú platia pravidlá Row Level Security: každý dopyt vidí len riadky
-- prihláseného používateľa. Server nastaví pred dopytmi:
--   SET LOCAL app.user_id = '<uuid používateľa>';

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TYPE user_role AS ENUM ('member', 'trainer');
CREATE TYPE client_link_status AS ENUM ('record_only', 'invited', 'linked', 'ended');
CREATE TYPE price_kind AS ENUM ('membership', 'product');
CREATE TYPE booking_status AS ENUM ('requested', 'confirmed', 'cancelled');

-- ---------------------------------------------------------------- používatelia

CREATE TABLE users (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email              citext NOT NULL UNIQUE,
  password_hash      text NOT NULL,
  display_name       text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 60),
  role               user_role NOT NULL DEFAULT 'member',
  city               text,
  -- Do rebríčkov sa človek dostane len vtedy, keď to sám zapne.
  leaderboard_opt_in boolean NOT NULL DEFAULT false,
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- Klient trénera. Tri stavy: len záznam u trénera (bez účtu), pozvaný, prepojený.
CREATE TABLE trainer_clients (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  client_user_id    uuid REFERENCES users (id) ON DELETE SET NULL,
  client_name       text NOT NULL CHECK (char_length(client_name) BETWEEN 1 AND 60),
  note              text,
  status            client_link_status NOT NULL DEFAULT 'record_only',
  invite_token_hash text UNIQUE,
  invite_expires_at timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trainer_id, client_user_id),
  CHECK (status <> 'linked' OR client_user_id IS NOT NULL)
);
CREATE INDEX trainer_clients_client_idx ON trainer_clients (client_user_id);

-- ------------------------------------------------------------------- fitká

CREATE TABLE gyms (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
  address    text,
  city       text,
  lat        double precision NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng        double precision NOT NULL CHECK (lng BETWEEN -180 AND 180),
  created_by uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX gyms_location_idx ON gyms (lat, lng);

-- Cenník permanentiek a produktov, ktorý pridávajú používatelia.
CREATE TABLE gym_prices (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id       uuid NOT NULL REFERENCES gyms (id) ON DELETE CASCADE,
  kind         price_kind NOT NULL,
  title        text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  price_cents  integer NOT NULL CHECK (price_cents >= 0),
  currency     char(3) NOT NULL DEFAULT 'EUR',
  period       text,
  submitted_by uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX gym_prices_gym_idx ON gym_prices (gym_id);

-- ----------------------------------------------------------------- tréningy

CREATE TABLE exercises (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL UNIQUE,
  muscle_group text,
  created_by   uuid REFERENCES users (id) ON DELETE SET NULL
);

-- Tréning patrí buď priamo používateľovi, alebo klientovi trénera.
CREATE TABLE workouts (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES users (id) ON DELETE CASCADE,
  trainer_client_id uuid REFERENCES trainer_clients (id) ON DELETE CASCADE,
  title             text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 120),
  scheduled_on      date,
  created_by        uuid REFERENCES users (id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(user_id, trainer_client_id) = 1)
);
CREATE INDEX workouts_user_idx ON workouts (user_id, scheduled_on);
CREATE INDEX workouts_client_idx ON workouts (trainer_client_id, scheduled_on);

CREATE TABLE workout_exercises (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id   uuid NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
  exercise_id  uuid NOT NULL REFERENCES exercises (id),
  position     integer NOT NULL CHECK (position >= 0),
  sets         integer NOT NULL CHECK (sets > 0),
  reps         integer NOT NULL CHECK (reps > 0),
  weight_kg    numeric(6, 2) CHECK (weight_kg >= 0),
  rest_seconds integer CHECK (rest_seconds >= 0),
  note         text,
  UNIQUE (workout_id, position)
);

-- Odcvičené série: z nich sa počíta progres a osobné rekordy.
CREATE TABLE set_logs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES users (id) ON DELETE CASCADE,
  trainer_client_id uuid REFERENCES trainer_clients (id) ON DELETE CASCADE,
  exercise_id       uuid NOT NULL REFERENCES exercises (id),
  workout_id        uuid REFERENCES workouts (id) ON DELETE SET NULL,
  reps              integer NOT NULL CHECK (reps > 0),
  weight_kg         numeric(6, 2) NOT NULL CHECK (weight_kg >= 0),
  performed_at      timestamptz NOT NULL DEFAULT now(),
  logged_by         uuid REFERENCES users (id) ON DELETE SET NULL,
  CHECK (num_nonnulls(user_id, trainer_client_id) = 1)
);
CREATE INDEX set_logs_user_idx ON set_logs (user_id, exercise_id, weight_kg DESC);
CREATE INDEX set_logs_client_idx ON set_logs (trainer_client_id, exercise_id, weight_kg DESC);

-- ------------------------------------------------------------------ správy

CREATE TABLE conversations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE conversation_members (
  conversation_id uuid NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, user_id)
);
CREATE INDEX conversation_members_user_idx ON conversation_members (user_id);

CREATE TABLE messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  sender_id       uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body            text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  sent_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX messages_conversation_idx ON messages (conversation_id, sent_at);

-- -------------------------------------------------------------- rezervácie

CREATE TABLE bookings (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id        uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  trainer_client_id uuid NOT NULL REFERENCES trainer_clients (id) ON DELETE CASCADE,
  during            tstzrange NOT NULL CHECK (NOT isempty(during)),
  status            booking_status NOT NULL DEFAULT 'requested',
  created_at        timestamptz NOT NULL DEFAULT now(),
  -- Tréner nemôže mať dva termíny v rovnakom čase.
  EXCLUDE USING gist (trainer_id WITH =, during WITH &&) WHERE (status <> 'cancelled')
);

-- ------------------------------------------------------- spoločné tréningy

CREATE TABLE partner_sessions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  gym_id     uuid REFERENCES gyms (id) ON DELETE SET NULL,
  starts_at  timestamptz NOT NULL,
  focus      text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX partner_sessions_time_idx ON partner_sessions (starts_at);

CREATE TABLE partner_session_members (
  session_id uuid NOT NULL REFERENCES partner_sessions (id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  PRIMARY KEY (session_id, user_id)
);

-- ------------------------------------------------------------ permanentky

CREATE TABLE member_passes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  gym_id      uuid REFERENCES gyms (id) ON DELETE SET NULL,
  label       text NOT NULL CHECK (char_length(label) BETWEEN 1 AND 120),
  code        text NOT NULL,
  valid_until date,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX member_passes_user_idx ON member_passes (user_id);
