-- ============================================================
-- RADUNI APP — Setup completo Supabase
-- Esegui questo unico file dall'SQL Editor di Supabase
-- (oppure i 6 file numerati in supabase/migrations/ in ordine).
-- Idempotente: puoi rieseguirlo senza danni.
-- ============================================================

\i 01_extensions.sql
\i 02_tables.sql
\i 03_indexes.sql
\i 04_rls.sql
\i 05_functions.sql
\i 06_storage.sql

-- Nota: la sintassi \i sopra funziona da psql ma non dall'SQL Editor di Supabase.
-- Da SQL Editor, esegui i file uno per volta in ordine numerico.
