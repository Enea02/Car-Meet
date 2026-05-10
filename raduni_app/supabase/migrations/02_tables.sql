-- Tabelle applicative
-- Eseguire dopo 01_extensions.sql

-- profiles: estende auth.users con campi applicativi
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE NOT NULL CHECK (length(username) BETWEEN 3 AND 30),
  display_name text NOT NULL DEFAULT 'Utente',
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- raduni: cuore dell'app, include un punto geografico PostGIS
CREATE TABLE IF NOT EXISTS public.raduni (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  location_name text NOT NULL,
  address text,
  location geography(Point, 4326) NOT NULL,
  entry_price_cents integer NOT NULL DEFAULT 0 CHECK (entry_price_cents >= 0),
  max_attendees integer CHECK (max_attendees IS NULL OR max_attendees > 0),
  cover_image_url text,
  status text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft', 'published', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- attendances: iscrizione di un visitatore a un raduno
CREATE TABLE IF NOT EXISTS public.attendances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  raduno_id uuid NOT NULL REFERENCES public.raduni(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (raduno_id, user_id)
);

-- auto: garage personale dell'utente
CREATE TABLE IF NOT EXISTS public.auto (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  make text NOT NULL,
  model text NOT NULL,
  year integer CHECK (year IS NULL OR (year >= 1900 AND year <= 2100)),
  description text,
  photo_urls text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- auto_exhibitions: registrazione di un'auto come esposta a un raduno
CREATE TABLE IF NOT EXISTS public.auto_exhibitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  raduno_id uuid NOT NULL REFERENCES public.raduni(id) ON DELETE CASCADE,
  auto_id uuid NOT NULL REFERENCES public.auto(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'approved'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (raduno_id, auto_id)
);
