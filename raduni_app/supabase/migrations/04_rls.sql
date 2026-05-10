-- Row Level Security
-- Eseguire dopo 02_tables.sql.
-- ATTENZIONE: senza RLS abilitate, qualsiasi utente potrebbe leggere/modificare qualsiasi dato.

-- ============================================================
-- profiles
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ============================================================
-- raduni
-- ============================================================
ALTER TABLE public.raduni ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "raduni_select_public_or_own" ON public.raduni;
CREATE POLICY "raduni_select_public_or_own" ON public.raduni
  FOR SELECT USING (
    status = 'published' OR auth.uid() = organizer_id
  );

DROP POLICY IF EXISTS "raduni_insert_own" ON public.raduni;
CREATE POLICY "raduni_insert_own" ON public.raduni
  FOR INSERT WITH CHECK (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "raduni_update_own" ON public.raduni;
CREATE POLICY "raduni_update_own" ON public.raduni
  FOR UPDATE USING (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "raduni_delete_own" ON public.raduni;
CREATE POLICY "raduni_delete_own" ON public.raduni
  FOR DELETE USING (auth.uid() = organizer_id);

-- ============================================================
-- attendances
-- ============================================================
ALTER TABLE public.attendances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "attendances_select_all" ON public.attendances;
CREATE POLICY "attendances_select_all" ON public.attendances
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "attendances_insert_self" ON public.attendances;
CREATE POLICY "attendances_insert_self" ON public.attendances
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "attendances_delete_self" ON public.attendances;
CREATE POLICY "attendances_delete_self" ON public.attendances
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- auto
-- ============================================================
ALTER TABLE public.auto ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auto_select_all" ON public.auto;
CREATE POLICY "auto_select_all" ON public.auto FOR SELECT USING (true);

DROP POLICY IF EXISTS "auto_insert_own" ON public.auto;
CREATE POLICY "auto_insert_own" ON public.auto
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "auto_update_own" ON public.auto;
CREATE POLICY "auto_update_own" ON public.auto
  FOR UPDATE USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "auto_delete_own" ON public.auto;
CREATE POLICY "auto_delete_own" ON public.auto
  FOR DELETE USING (auth.uid() = owner_id);

-- ============================================================
-- auto_exhibitions
-- ============================================================
ALTER TABLE public.auto_exhibitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "exhibitions_select_all" ON public.auto_exhibitions;
CREATE POLICY "exhibitions_select_all" ON public.auto_exhibitions
  FOR SELECT USING (true);

-- Solo il proprietario dell'auto può registrarla
DROP POLICY IF EXISTS "exhibitions_insert_owner" ON public.auto_exhibitions;
CREATE POLICY "exhibitions_insert_owner" ON public.auto_exhibitions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.auto a
      WHERE a.id = auto_id AND a.owner_id = auth.uid()
    )
  );

-- L'organizzatore del raduno può aggiornare lo status (approvare/rifiutare)
DROP POLICY IF EXISTS "exhibitions_update_organizer" ON public.auto_exhibitions;
CREATE POLICY "exhibitions_update_organizer" ON public.auto_exhibitions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.raduni r
      WHERE r.id = raduno_id AND r.organizer_id = auth.uid()
    )
  );

-- Il proprietario dell'auto o l'organizzatore possono cancellare
DROP POLICY IF EXISTS "exhibitions_delete_owner_or_organizer" ON public.auto_exhibitions;
CREATE POLICY "exhibitions_delete_owner_or_organizer" ON public.auto_exhibitions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.auto a
      WHERE a.id = auto_id AND a.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.raduni r
      WHERE r.id = raduno_id AND r.organizer_id = auth.uid()
    )
  );
