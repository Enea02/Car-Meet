-- Estensioni richieste
-- PostGIS è il cuore della query "raduni vicini".
-- Su Supabase puoi anche abilitarlo dal pannello Database > Extensions.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- per gen_random_uuid()
