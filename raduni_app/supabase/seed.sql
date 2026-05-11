-- Seed data per Car-Meet
-- Eseguire dopo tutte le migrazioni (solo ambiente locale/staging).

-- ============================================================
-- 0. AUTH.USERS  (richiesto dalla FK profiles.id → auth.users.id)
-- ============================================================
INSERT INTO auth.users (
  id, aud, role,
  email, encrypted_password,
  email_confirmed_at,
  created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin
) VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated',
    'marco.rossi@example.com', crypt('Password123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated',
    'giulia.bianchi@example.com', crypt('Password123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated',
    'luca.ferrari@example.com', crypt('Password123!', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    false
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 1. PROFILES
-- ============================================================
INSERT INTO public.profiles (id, username, display_name, avatar_url) VALUES
  ('00000000-0000-0000-0000-000000000001', 'marco_rossi',   'Marco Rossi',   NULL),
  ('00000000-0000-0000-0000-000000000002', 'giulia_bianchi', 'Giulia Bianchi', NULL),
  ('00000000-0000-0000-0000-000000000003', 'luca_ferrari',  'Luca Ferrari',  NULL)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. RADUNI
-- ============================================================
-- location: ST_MakePoint(longitude, latitude)
INSERT INTO public.raduni (
  id, organizer_id, title, description,
  start_at, end_at,
  location_name, address, location,
  entry_price_cents, max_attendees, status
) VALUES
  (
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Raduno Auto d''Epoca – Monza 2026',
    'Grande raduno annuale di auto storiche nel cuore della città di Monza. Ammesse vetture precedenti il 1980.',
    '2026-06-14 09:00:00+02', '2026-06-14 18:00:00+02',
    'Piazza Roma, Monza',
    'Piazza Roma, 20900 Monza MB',
    ST_MakePoint(9.2736, 45.5845)::geography,
    500,   -- 5,00 €
    200,
    'published'
  ),
  (
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    'Supercar Sunday – Milano',
    'Esposizione di supercar e hypercar nel centro di Milano. Ingresso libero.',
    '2026-07-05 10:00:00+02', '2026-07-05 17:00:00+02',
    'Piazza Duomo, Milano',
    'Piazza del Duomo, 20122 Milano MI',
    ST_MakePoint(9.1895, 45.4642)::geography,
    0,
    NULL,
    'published'
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000003',
    'JDM Night – Bologna',
    'Raduno notturno dedicato alle auto giapponesi anni ''90. Parcheggio gratuito.',
    '2026-08-22 20:00:00+02', '2026-08-23 01:00:00+02',
    'Parco Nord, Bologna',
    'Via Ferrarese, 40128 Bologna BO',
    ST_MakePoint(11.3426, 44.5220)::geography,
    300,   -- 3,00 €
    150,
    'published'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. AUTO
-- ============================================================
INSERT INTO public.auto (id, owner_id, make, model, year, description, photo_urls) VALUES
  (
    'b0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Alfa Romeo', 'Spider 2000',
    1975,
    'Restauro completo, vernice originale rosso Alfa, capote nuova.',
    '{}'
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    'Ferrari', '488 GTB',
    2017,
    'Ferrari 488 GTB in rosso Corsa, 1.200 km certificati.',
    '{}'
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000003',
    'Mazda', 'RX-7 FD',
    1994,
    'RX-7 FD3S originale Giappone, motore 13B revisionato, nessuna modifica alla carrozzeria.',
    '{}'
  ),
  (
    'b0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    'Fiat', '500 L',
    1972,
    'Cinquecento storica con motivo originale, colore giallo Positano.',
    '{}'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. ATTENDANCES
-- ============================================================
INSERT INTO public.attendances (raduno_id, user_id) VALUES
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002'),
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003'),
  ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (raduno_id, user_id) DO NOTHING;

-- ============================================================
-- 5. AUTO_EXHIBITIONS
-- ============================================================
INSERT INTO public.auto_exhibitions (raduno_id, auto_id, status) VALUES
  -- Raduno Monza: Spider di Marco esposta
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'approved'),
  -- Raduno Monza: Fiat 500 di Marco esposta
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', 'approved'),
  -- Supercar Sunday: Ferrari di Giulia esposta
  ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'approved'),
  -- JDM Night: RX-7 di Luca esposta
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'approved')
ON CONFLICT (raduno_id, auto_id) DO NOTHING;
