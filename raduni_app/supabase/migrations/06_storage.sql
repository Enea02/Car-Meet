-- Storage buckets e relative policy
-- ATTENZIONE: i bucket vanno creati anche dal pannello Supabase
-- (Storage > New bucket) — questo file aggiunge solo le policy.
-- Bucket richiesti, tutti PUBLIC (read pubblico):
--   * avatars
--   * raduni-covers
--   * auto-photos
-- In alternativa, esegui la sezione "create bucket" qui sotto.

-- ============================================================
-- (Opzionale) creazione bucket via SQL
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars', 'avatars', true),
  ('raduni-covers', 'raduni-covers', true),
  ('auto-photos', 'auto-photos', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- ============================================================
-- Policy storage: lettura pubblica, write nel proprio prefisso
-- ============================================================

-- Lettura pubblica
DROP POLICY IF EXISTS "public_read_avatars" ON storage.objects;
CREATE POLICY "public_read_avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "public_read_raduni_covers" ON storage.objects;
CREATE POLICY "public_read_raduni_covers" ON storage.objects
  FOR SELECT USING (bucket_id = 'raduni-covers');

DROP POLICY IF EXISTS "public_read_auto_photos" ON storage.objects;
CREATE POLICY "public_read_auto_photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'auto-photos');

-- Scrittura: l'utente autenticato può solo nel proprio prefisso (cartella = userId)
DROP POLICY IF EXISTS "owner_write_avatars" ON storage.objects;
CREATE POLICY "owner_write_avatars" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_update_avatars" ON storage.objects;
CREATE POLICY "owner_update_avatars" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_delete_avatars" ON storage.objects;
CREATE POLICY "owner_delete_avatars" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_write_covers" ON storage.objects;
CREATE POLICY "owner_write_covers" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'raduni-covers'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_delete_covers" ON storage.objects;
CREATE POLICY "owner_delete_covers" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'raduni-covers'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_write_auto_photos" ON storage.objects;
CREATE POLICY "owner_write_auto_photos" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'auto-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "owner_delete_auto_photos" ON storage.objects;
CREATE POLICY "owner_delete_auto_photos" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'auto-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
