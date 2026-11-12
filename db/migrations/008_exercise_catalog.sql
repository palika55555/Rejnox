-- Rejnox: základný katalóg cvikov.
-- ID sú pevné, aby ich appka mala zabudované a vedela zapisovať aj bez internetu
-- (rovnaký zoznam je v lib/features/training/data/exercise_catalog.dart).

INSERT INTO exercises (id, name, muscle_group) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Drep s činkou', 'nohy'),
  ('00000000-0000-4000-8000-000000000002', 'Rumunský mŕtvy ťah', 'nohy'),
  ('00000000-0000-4000-8000-000000000003', 'Mŕtvy ťah', 'chrbat'),
  ('00000000-0000-4000-8000-000000000004', 'Bench press', 'hrudnik'),
  ('00000000-0000-4000-8000-000000000005', 'Tlaky s jednoručkami na šikmej lavici', 'hrudnik'),
  ('00000000-0000-4000-8000-000000000006', 'Príťahy v predklone', 'chrbat'),
  ('00000000-0000-4000-8000-000000000007', 'Zhyby', 'chrbat'),
  ('00000000-0000-4000-8000-000000000008', 'Tlak nad hlavu', 'ramena'),
  ('00000000-0000-4000-8000-000000000009', 'Bulharské výpady', 'nohy'),
  ('00000000-0000-4000-8000-00000000000a', 'Hip thrust', 'nohy'),
  ('00000000-0000-4000-8000-00000000000b', 'Bicepsový zdvih', 'ruky'),
  ('00000000-0000-4000-8000-00000000000c', 'Francúzsky tlak', 'ruky')
ON CONFLICT (id) DO NOTHING;
