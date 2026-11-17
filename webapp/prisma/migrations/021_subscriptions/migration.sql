-- Rejnox: predplatné používateľa (zatiaľ len podklad pre AI funkcie).
-- AI volania stoja peniaze, preto ich smie použiť len používateľ s aktívnym predplatným.
-- Riadok sem zapisuje výlučne server po overení nákupu (Apple / Google / Stripe) alebo
-- vlastník databázy ručne (provider = 'manual'). Aplikácia (rola rejnox_app) do tabuľky
-- nemá priamy prístup, takže si predplatné nemôže nastaviť sama, môže sa len opýtať,
-- či ho má, cez funkciu has_active_subscription().

CREATE TABLE subscriptions (
  user_id            uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  status             text NOT NULL CHECK (status IN ('active', 'canceled', 'expired')),
  provider           text NOT NULL CHECK (provider IN ('apple', 'google', 'stripe', 'manual')),
  -- Do kedy je zaplatené; po tomto čase predplatné neplatí, aj keď status ostal 'active'.
  current_period_end timestamptz NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Má prihlásený používateľ platné predplatné? ('canceled' platí do konca zaplateného obdobia.)
CREATE FUNCTION has_active_subscription() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM subscriptions s
    WHERE s.user_id = app_user_id()
      AND s.status IN ('active', 'canceled')
      AND s.current_period_end > now()
  )
$$;

REVOKE ALL ON FUNCTION has_active_subscription() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION has_active_subscription() TO rejnox_app;
