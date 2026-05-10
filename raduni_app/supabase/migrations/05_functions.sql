-- Funzioni e trigger

-- ============================================================
-- raduni_nearby: query geospaziale chiamata via RPC dall'app
-- ============================================================
CREATE OR REPLACE FUNCTION public.raduni_nearby(
  user_lat double precision,
  user_lng double precision,
  radius_km double precision DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  organizer_id uuid,
  title text,
  description text,
  start_at timestamptz,
  end_at timestamptz,
  location_name text,
  address text,
  lat double precision,
  lng double precision,
  entry_price_cents integer,
  max_attendees integer,
  cover_image_url text,
  status text,
  created_at timestamptz,
  distance_km double precision
)
LANGUAGE sql STABLE AS $$
  SELECT
    r.id,
    r.organizer_id,
    r.title,
    r.description,
    r.start_at,
    r.end_at,
    r.location_name,
    r.address,
    ST_Y(r.location::geometry) AS lat,
    ST_X(r.location::geometry) AS lng,
    r.entry_price_cents,
    r.max_attendees,
    r.cover_image_url,
    r.status,
    r.created_at,
    ST_Distance(
      r.location,
      ST_MakePoint(user_lng, user_lat)::geography
    ) / 1000.0 AS distance_km
  FROM public.raduni r
  WHERE r.status = 'published'
    AND r.start_at > now()
    AND ST_DWithin(
      r.location,
      ST_MakePoint(user_lng, user_lat)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC
  LIMIT 100;
$$;

-- ============================================================
-- handle_new_user: trigger per creare la riga profiles dopo signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_username text;
  final_username text;
  suffix int := 0;
BEGIN
  base_username := lower(regexp_replace(
    coalesce(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    '[^a-z0-9_]', '', 'g'
  ));
  IF base_username IS NULL OR length(base_username) < 3 THEN
    base_username := 'user_' || substr(NEW.id::text, 1, 8);
  END IF;
  final_username := base_username;

  WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = final_username) LOOP
    suffix := suffix + 1;
    final_username := base_username || suffix::text;
  END LOOP;

  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    final_username,
    coalesce(NEW.raw_user_meta_data->>'display_name', 'Utente')
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
