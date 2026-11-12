-- LEN PRE VÝVOJ: ukážkové fitká po svete, aby mapa nebola prázdna.
-- Nie je to migrácia, do ostrej databázy sa nespúšťa.
-- Spustenie: psql -U postgres -h localhost -d rejnox -f db/seeds/demo_gyms.sql

INSERT INTO gyms (id, name, city, lat, lng, opening_hours, tags) VALUES
  ('00000000-0000-4000-9000-000000000001', 'Gym Fit Nitra', 'Nitra', 48.3076, 18.0845, 'Nonstop', '{"Silový tréning","Kardio","Funkčný tréning"}'),
  ('00000000-0000-4000-9000-000000000002', 'Iron Hall Nitra', 'Nitra', 48.3191, 18.0990, 'Po–Pi 6:00–22:00, So–Ne 8:00–20:00', '{"Silový trojboj","Kulturistika"}'),
  ('00000000-0000-4000-9000-000000000003', 'Klokočina Strength', 'Nitra', 48.3021, 18.0547, 'Po–Ne 7:00–21:00', '{"Silový tréning","Skupinové lekcie"}'),
  ('00000000-0000-4000-9000-000000000004', 'Danube Barbell Club', 'Bratislava', 48.1440, 17.1130, 'Nonstop', '{"Silový tréning","Kardio","Sauna"}'),
  ('00000000-0000-4000-9000-000000000005', 'Petržalka Power Gym', 'Bratislava', 48.1213, 17.1097, NULL, '{"Kardio","Skupinové lekcie"}'),
  ('00000000-0000-4000-9000-000000000006', 'Žilina Lift House', 'Žilina', 49.2231, 18.7394, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000007', 'Tatry Training Center', 'Banská Bystrica', 48.7363, 19.1462, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000008', 'Východ Fitness Košice', 'Košice', 48.7164, 21.2611, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000009', 'Vltava Strength Lab', 'Praha', 50.0755, 14.4378, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000010', 'Ringstraße Athletics', 'Viedeň', 48.2082, 16.3738, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000011', 'Duna Iron Club', 'Budapešť', 47.4979, 19.0402, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000012', 'Thames Barbell', 'Londýn', 51.5072, -0.1276, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000013', 'Hudson Strength', 'New York', 40.7128, -74.0060, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000014', 'Lakeshore Lifting', 'Toronto', 43.6532, -79.3832, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000015', 'Pacific Muscle Yard', 'Los Angeles', 34.0522, -118.2437, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000016', 'Paulista Performance', 'São Paulo', -23.5505, -46.6333, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000017', 'Table Mountain Gym', 'Kapské Mesto', -33.9249, 18.4241, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000018', 'Desert Iron', 'Dubaj', 25.2048, 55.2708, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000019', 'Shibuya Power Dojo', 'Tokio', 35.6762, 139.6503, NULL, '{}'),
  ('00000000-0000-4000-9000-000000000020', 'Harbour Strength', 'Sydney', -33.8688, 151.2093, NULL, '{}')
ON CONFLICT (id) DO NOTHING;
