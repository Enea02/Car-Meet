# RADUNI APP — Istruzioni per te

Questo file elenca **solo** i passi che richiedono il tuo intervento.
Tutto il codice Flutter (modelli, repository, provider, schermate, mappa, garage, profilo) è già stato scritto.

> Stima tempi: **30–45 minuti** la prima volta, di cui ~10 di attesa per la creazione del progetto Supabase.

---

## Indice

1. [Cosa è già fatto](#1-cosa-è-già-fatto)
2. [Crea il progetto Supabase](#2-crea-il-progetto-supabase)
3. [Esegui le migrazioni SQL](#3-esegui-le-migrazioni-sql)
4. [Crea i bucket di Storage](#4-crea-i-bucket-di-storage)
5. [Recupera URL + anon key](#5-recupera-url--anon-key)
6. [Eseguire l'app](#6-eseguire-lapp)
7. [Validazione](#7-validazione)
8. [Troubleshooting](#8-troubleshooting)
9. [Cosa è rimandato](#9-cosa-è-rimandato)

---

## 1. Cosa è già fatto

✅ **Codice Flutter completo** (`lib/`)
- `core/`: config Supabase, tema Material 3, router go_router con redirect su sessione, utility (PostGIS WKT, formatter distanza)
- `features/auth/`: login, signup, repository, provider Riverpod
- `features/raduni/`: modello, repository, provider, home (lista vicini), dettaglio (con iscrizione/auto esposizione/eliminazione), creazione (form + pin sulla mappa + upload cover compressa)
- `features/map/`: location service con permessi, schermata mappa OSM con marker raduni, debounce, slider raggio, fallback se GPS negato
- `features/auto/`: garage, dettaglio, creazione auto con foto multiple compresse, esposizioni
- `features/profile/`: schermata profilo con avatar, modifica username/display name, logout
- `shared/widgets/`: card raduno, loader, errori, empty states

✅ **`pubspec.yaml`** allineato (aggiunto `flutter_image_compress` e `flutter_localizations`, `intl` aggiornato a 0.20.2 per compatibilità).

✅ **Permessi iOS/Android** già configurati nel progetto.

✅ **Migrazioni SQL** (`supabase/migrations/`) — vedi sezione 3.

✅ `flutter analyze` ritorna **0 errori** (solo info di stile).

---

## 2. Crea il progetto Supabase

> Salta questa sezione se hai già fatto il setup Supabase descritto in `docs/00-SETUP-MACBOOK.md`.

1. Vai su [supabase.com](https://supabase.com), iscriviti / fai login.
2. Clicca **New Project**:
   - Nome: `raduni-app`
   - Password DB: usa una password robusta e salvala in un password manager
   - Region: **`eu-central-1` (Frankfurt)** — bassa latenza dall'Italia
3. Aspetta ~2 minuti che il progetto si crei.
4. Vai su **Database → Extensions**, cerca `postgis` → **Enable**.
   *(Se il file `01_extensions.sql` riesce a creare PostGIS direttamente, puoi saltare questo passo manuale.)*

---

## 3. Esegui le migrazioni SQL

Apri **SQL Editor** dal menu di sinistra di Supabase, poi esegui in ordine i 6 file presenti in `supabase/migrations/`:

| Ordine | File | Cosa fa |
|---|---|---|
| 1 | `01_extensions.sql` | Abilita PostGIS e pgcrypto |
| 2 | `02_tables.sql` | Crea `profiles`, `raduni`, `attendances`, `auto`, `auto_exhibitions` |
| 3 | `03_indexes.sql` | Indici, incluso GIST geospaziale su `raduni.location` |
| 4 | `04_rls.sql` | Row Level Security su tutte le tabelle (CRITICO per sicurezza) |
| 5 | `05_functions.sql` | RPC `raduni_nearby` + trigger `handle_new_user` |
| 6 | `06_storage.sql` | Crea i 3 bucket di Storage e le relative policy |

**Procedura per ogni file:**
1. Apri il file localmente, copia il contenuto.
2. SQL Editor → **New query** → incolla → **Run**.
3. Verifica che il risultato sia "Success. No rows returned".

> Le migrazioni sono **idempotenti**: puoi rieseguirle senza danni (`CREATE … IF NOT EXISTS`, `DROP POLICY IF EXISTS` prima di ricrearle, `ON CONFLICT DO UPDATE` per i bucket).

---

## 4. Crea i bucket di Storage

Il file `06_storage.sql` prova a crearli automaticamente. Se preferisci farlo dal pannello (o se l'INSERT su `storage.buckets` fallisce per permessi), vai su **Storage → New bucket** e crea:

| Bucket | Public? |
|---|---|
| `avatars` | sì |
| `raduni-covers` | sì |
| `auto-photos` | sì |

Le policy di scrittura "owner-only via prefisso `userId/`" sono già definite in `06_storage.sql`.

---

## 5. Recupera URL + anon key

Vai su **Project Settings → API** (o **Settings → API Keys** nelle versioni più recenti del pannello). Segna:

- `Project URL` → es. `https://abcd1234.supabase.co`
- `anon public` key → JWT che inizia con `eyJ…`

> ⚠️ **NON** usare la `service_role` key nell'app. Solo lato server.

---

## 6. Eseguire l'app

L'app legge la config con `String.fromEnvironment`, quindi va passata via `--dart-define`. Niente file `.env` da committare per sbaglio.

### 6.1 Installa le dipendenze (già fatto da me, ma se serve)

```bash
flutter pub get
```

### 6.2 Avvia un simulatore

```bash
# iOS
open -a Simulator

# Android (da Android Studio: Virtual Device Manager → Play)
```

### 6.3 Lancia l'app

Sostituisci `<TUOI_VALORI>` con quelli del passo 5:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://dblkwbgkfrugetjlfrfb.supabase.co\
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRibGt3YmdrZnJ1Z2V0amxmcmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxODE5OTgsImV4cCI6MjA5Mzc1Nzk5OH0.xEldtNGzTdIBH3mJGQbsEsrx7ATnLLYtm1wKNVEhxWo
```

> Se vedi la schermata "Configurazione mancante", non hai passato i `--dart-define`.

### 6.4 Comodo: salva i define in VS Code

Crea `.vscode/launch.json` (NON committarlo se contiene chiavi reali):

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "raduni_app (dev)",
      "request": "launch",
      "type": "dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://abcd1234.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs..."
      ]
    }
  ]
}
```

Poi premi `F5` per avviare.

---

## 7. Validazione

Una volta avviata l'app:

- [ ] **Signup** con email + password + display name → ricevi mail di conferma → click sul link → app ti porta su `/home/raduni`
   - In dev puoi disabilitare la conferma email da Supabase: **Authentication → Settings → "Confirm email"** off.
- [ ] **Logout** dalla schermata Profilo → torni a `/login`
- [ ] **Login** con le stesse credenziali
- [ ] Vai sulla **Mappa**: accetta permessi GPS → vedi un cerchio sul tuo punto
- [ ] **Crea raduno**: titolo, data futura, sposta il pin sulla mappa, salva
- [ ] Torna sulla **Home raduni**: vedi il raduno entro 50km
- [ ] Apri il **dettaglio** del raduno → "Iscriviti" funziona, contatore iscritti aumenta
- [ ] **Garage → Aggiungi auto**: marca, modello, anno, foto multiple → salva
- [ ] Sul dettaglio raduno → "Esponi una mia auto" → seleziona auto → la vedi nella lista esposte
- [ ] **Profilo**: cambia avatar, salva → l'avatar compare in tab profilo

### Test RLS (sicurezza)

Da **SQL Editor** di Supabase, lancia:

```sql
-- Simula utente anon (nessuna auth)
SET LOCAL ROLE anon;
SELECT * FROM raduni; -- deve mostrare solo i 'published'
INSERT INTO raduni (organizer_id, title, start_at, location_name, location)
VALUES (gen_random_uuid(), 'hack', now(), 'x', ST_MakePoint(9.19, 45.46)::geography);
-- deve fallire con: permission denied / RLS violation
```

---

## 8. Troubleshooting

| Sintomo | Causa probabile | Fix |
|---|---|---|
| Schermata "Configurazione mancante" | manca `--dart-define` | rilancia con i define |
| `function raduni_nearby does not exist` | non hai eseguito `05_functions.sql` | esegui il file |
| `new row violates row-level security policy` su INSERT raduno | manca la policy `raduni_insert_own` (o sei loggato come utente diverso da `organizer_id`) | ricarica `04_rls.sql`; controlla che `auth.uid()` non sia null |
| Foto upload → `403` o `permission denied` | manca la policy storage owner-only | ricarica `06_storage.sql` |
| `Geolocator` chiede permessi all'infinito su iOS | clean build dopo aver toccato `Info.plist` | `flutter clean && flutter run` |
| Build iOS rotta dopo cambi pubspec | pod outdated | `cd ios && pod install --repo-update && cd ..` |
| Mappa bianca | tile OSM non scaricano | controlla connessione; alcuni network aziendali bloccano `tile.openstreetmap.org` |
| Real-time non aggiorna | replica non abilitata sulla tabella | Supabase → Database → Replication → abilita su `raduni` |

---

## 9. Cosa è rimandato

Volutamente fuori dall'MVP (in linea con `02-FASI-IMPLEMENTAZIONE.md`):

- **Sign in with Apple / Google OAuth** — per ora solo email+password (App Store esige Sign in with Apple solo se hai altri OAuth).
- **Push notifications (FCM)** — niente Firebase per ora.
- **Pagamenti Stripe** — fase 6 futura, richiede Edge Function lato server.
- **Geocoding indirizzo → coordinate** — per ora si usa il pin manuale sulla mappa (zero costi, scelta motivata nel doc 02 §3).
- **Real-time list streaming attivo by default** — la home usa `fetchNearby` (RPC). Se vuoi real-time reattivo, swap su `raduniListStreamProvider` (già esposto in `raduni_providers.dart`).
- **Splash screen / icona brandizzata** — fase 5, richiede asset grafici.
- **Onboarding 3 schermate** — fase 5.

---

## 10. Sviluppo successivo

Quando aggiungi codice:

- Foto pesanti? Hai già `flutter_image_compress` integrato (1600px / 80q) — riusalo.
- Nuove tabelle? Aggiungi un `07_xxx.sql` in `supabase/migrations/` ed esegui solo quello.
- Modifiche RLS? Ricarica solo `04_rls.sql` (è idempotente).
- Bug Mapbox / qualità OSM scarsa? In `map_screen.dart` cambia `urlTemplate` per puntare a Stadia Maps o Mapbox tiles (richiede chiave).

Buon lavoro! 🚗💨
