-- Indici per query veloci
-- Eseguire dopo 02_tables.sql

-- Indice geospaziale GIST sul campo location (rende ST_DWithin O(log n))
CREATE INDEX IF NOT EXISTS idx_raduni_location ON public.raduni USING GIST(location);

-- Filtri "raduni futuri"
CREATE INDEX IF NOT EXISTS idx_raduni_start_at ON public.raduni(start_at);

-- Filtri "raduni di un organizzatore"
CREATE INDEX IF NOT EXISTS idx_raduni_organizer ON public.raduni(organizer_id);

-- Indici FK per join rapidi
CREATE INDEX IF NOT EXISTS idx_attendances_raduno ON public.attendances(raduno_id);
CREATE INDEX IF NOT EXISTS idx_attendances_user ON public.attendances(user_id);
CREATE INDEX IF NOT EXISTS idx_auto_owner ON public.auto(owner_id);
CREATE INDEX IF NOT EXISTS idx_exhibitions_raduno ON public.auto_exhibitions(raduno_id);
CREATE INDEX IF NOT EXISTS idx_exhibitions_auto ON public.auto_exhibitions(auto_id);
