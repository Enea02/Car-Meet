# RADUNI APP — ARCHITETTURA

**Documento:** 01 di 03 — Architettura applicativa e modello dati
**Versione:** 1.0
**Data:** 7 Maggio 2026
**Target:** Sviluppatore Flutter, conoscenza base di SQL e API REST

> **Obiettivo:** Definire le decisioni architetturali, lo stack tecnico, il modello dati e la struttura del progetto, in modo che le successive fasi di implementazione (vedi `02-FASI-IMPLEMENTAZIONE.md`) seguano un disegno coerente.

---

## Indice

1. Riepilogo Esecutivo
2. Stack Tecnologico — Decisioni Motivate
3. Struttura Cartelle del Progetto
4. State Management con Riverpod
5. Modello Dati (Supabase / PostgreSQL)
6. Row Level Security
7. Query Geospaziale "Raduni Vicini"
8. Flusso Autenticazione
9. Flusso Mappa e Geolocalizzazione
10. Storage Foto (Supabase Storage)
11. Routing con go_router

---

## 1. Riepilogo Esecutivo

### Obiettivo
App mobile (iOS + Android) in Flutter per gestire **raduni di auto**: un utente può creare un raduno con luogo, data e prezzo d'ingresso; altri utenti possono iscriversi come visitatori o registrare la propria auto per esporla; una mappa mostra in tempo reale i raduni attivi nelle vicinanze.

### Approccio Raccomandato

- **Fase 1:** Auth + scheletro app + modello dati
- **Fase 2:** Creazione e visualizzazione raduni (CRUD)
- **Fase 3:** Mappa interattiva con raduni geolocalizzati
- **Fase 4:** Registrazione auto e iscrizione raduni
- **Fase 5:** Polish, notifiche, profilo utente
- **Fase 6 (futura):** Pagamenti integrati con Stripe

### Punto Chiave

> ⚠️ **La query "raduni vicini al mio punto" è il cuore tecnico dell'app.** Va risolta lato database con PostGIS, non lato client. Calcolare distanze su 10.000 raduni in Dart bloccherebbe la UI. Vedi sezione 7.

### Benefici Principali

- **Time-to-market rapido:** Supabase elimina la necessità di scrivere un backend custom
- **Costi bassi all'inizio:** tier gratuito Supabase copre tranquillamente i primi mesi
- **Scalabilità:** PostgreSQL + PostGIS gestiscono milioni di righe senza problemi
- **Real-time gratis:** Supabase ha subscription real-time native, utili per lista raduni e iscrizioni live
- **Sicurezza by design:** Row Level Security a livello di tabella

---

## 2. Stack Tecnologico — Decisioni Motivate

### 2.1 Backend: Supabase

**Problema:** servono auth, database con query geospaziali, storage per foto, real-time updates per lista raduni.

**Opzioni Valutate:**

1. **Firebase:** rapidissimo da configurare, ma Firestore non supporta query geospaziali native efficienti (servono workaround con geohash). Storage costoso a scala.
2. **Supabase:** PostgreSQL con PostGIS (estensione geospaziale standard), auth integrata, storage S3-compatible, real-time. Open source, self-hostable se servisse in futuro.
3. **Backend custom (Node + Postgres):** massimo controllo, ma 4-6 settimane di lavoro extra solo per replicare ciò che Supabase dà out-of-the-box.

**Decisione:** **Supabase**.

**Motivazione:** la feature "raduni nel raggio di X km" è centrale e PostGIS la risolve con un singolo `ST_DWithin`. Su Firebase avresti dovuto importare librerie geohash-based con limitazioni di precisione. Tradeoff accettato: vendor lock-in più alto rispetto a un backend custom, mitigato dal fatto che Supabase è open source e migrabile su Postgres puro in futuro.

### 2.2 State Management: Riverpod

**Opzioni Valutate:**

1. **Provider:** semplice ma verboso, soffre con stati derivati complessi
2. **BLoC:** ottimo ma boilerplate elevato, curva d'apprendimento ripida
3. **Riverpod:** evoluzione di Provider dello stesso autore, type-safe, testabile, async nativo

**Decisione:** **Riverpod 2.x** con code generation (`riverpod_generator`).

**Motivazione:** la app ha molti stati asincroni (sessione utente, lista raduni, posizione GPS, mappa). Riverpod gestisce gli `AsyncValue<T>` in modo idiomatico ed evita gran parte del boilerplate di BLoC.

### 2.3 Mappa: flutter_map (non Google Maps)

**Opzioni Valutate:**

1. **google_maps_flutter:** UX premium ma richiede API key Google con billing attivo, costi non trascurabili a scala
2. **mapbox_gl:** ottima qualità, free tier generoso, ma SDK più pesante e config iOS/Android non banale
3. **flutter_map:** widget puro Dart che usa tile OpenStreetMap, zero costi, zero chiavi API

**Decisione:** **flutter_map** con tile OSM in fase 1.

**Motivazione:** per un MVP partire senza dipendere da billing Google è strategico. Se in futuro la qualità dei tile OSM non basta, `flutter_map` supporta provider alternativi (Mapbox, Stadia Maps) cambiando una sola URL.

### 2.4 Routing: go_router

**Decisione:** `go_router` ufficiale Flutter team. Supporta deep linking nativo, utile per condividere link a un raduno specifico (`raduni-app://raduno/123`).

---

## 3. Struttura Cartelle del Progetto

Sotto `lib/`, organizzazione **feature-first** (non layer-first):

```
lib/
├── main.dart
├── app.dart                        # MaterialApp + go_router config
├── core/
│   ├── config/
│   │   └── supabase_config.dart    # URL + anon key
│   ├── theme/
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart
│   └── utils/
│       └── distance_formatter.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   └── providers/
│   │       └── auth_providers.dart
│   ├── raduni/
│   │   ├── data/
│   │   │   ├── raduni_repository.dart
│   │   │   └── raduni_model.dart
│   │   ├── presentation/
│   │   │   ├── home_screen.dart
│   │   │   ├── raduno_detail_screen.dart
│   │   │   └── create_raduno_screen.dart
│   │   └── providers/
│   │       └── raduni_providers.dart
│   ├── map/
│   │   ├── data/
│   │   │   └── location_service.dart
│   │   └── presentation/
│   │       └── map_screen.dart
│   ├── auto/
│   │   ├── data/
│   │   │   ├── auto_model.dart
│   │   │   └── auto_repository.dart
│   │   └── presentation/
│   │       ├── my_garage_screen.dart
│   │       └── register_auto_screen.dart
│   └── profile/
│       └── presentation/
│           └── profile_screen.dart
└── shared/
    └── widgets/
        ├── raduno_card.dart
        └── loading_indicator.dart
```

> ✅ **Beneficio:** struttura feature-first significa che eliminare una feature o lavorarci in team senza conflitti git è banale. Tutto ciò che riguarda i "raduni" sta in `features/raduni/`.

---

## 4. State Management con Riverpod

### 4.1 Pattern di Base

Riverpod gestisce tre tipi di provider:

| Tipo | Quando | Esempio |
|---|---|---|
| `Provider` | Valore costante o servizio singleton | Repository, Supabase client |
| `FutureProvider` | Dato fetched una sola volta | Profilo utente corrente |
| `StreamProvider` | Dato che cambia nel tempo | Lista raduni (real-time da Supabase) |

### 4.2 Esempio: Provider lista raduni

```dart
// features/raduni/providers/raduni_providers.dart
@riverpod
Stream<List<Raduno>> raduniNearby(
  RaduniNearbyRef ref, {
  required double lat,
  required double lng,
  double radiusKm = 50,
}) {
  final repo = ref.watch(raduniRepositoryProvider);
  return repo.watchNearby(lat: lat, lng: lng, radiusKm: radiusKm);
}
```

**Punti chiave del pattern:**

- Il provider è **dichiarativo:** la UI si limita a `ref.watch(...)` e ottiene un `AsyncValue<List<Raduno>>`
- Auto-dispose: quando nessuna UI è in ascolto, lo stream si chiude (no memory leak)
- Cache: se due schermate guardano lo stesso provider con gli stessi parametri, condividono la stessa subscription

### 4.3 Esempio: UI che consuma il provider

```dart
// pseudo-code, da espandere in fase implementativa
class HomeScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(currentPositionProvider);

    return position.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Text('Errore GPS: $e'),
      data: (pos) {
        final raduni = ref.watch(raduniNearbyProvider(
          lat: pos.latitude,
          lng: pos.longitude,
        ));

        return raduni.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => Text('Errore: $e'),
          data: (lista) => ListView(...),
        );
      },
    );
  }
}
```

---

## 5. Modello Dati (Supabase / PostgreSQL)

### 5.1 Tabella `profiles`

Estende `auth.users` di Supabase con campi applicativi.

| Campo | Tipo | Descrizione |
|---|---|---|
| **id** | uuid | Primary key, FK a `auth.users.id` |
| username | text | Unique, lunghezza 3-30 |
| display_name | text | Nome mostrato negli eventi |
| avatar_url | text | URL foto profilo (Supabase Storage) |
| created_at | timestamptz | Default `now()` |

### 5.2 Tabella `raduni`

Cuore dell'applicazione.

| Campo | Tipo | Descrizione |
|---|---|---|
| **id** | uuid | Primary key, default `gen_random_uuid()` |
| organizer_id | uuid | FK a `profiles.id`, NOT NULL |
| title | text | Titolo raduno, NOT NULL |
| description | text | Descrizione long-form |
| start_at | timestamptz | Data/ora inizio |
| end_at | timestamptz | Data/ora fine |
| location_name | text | Nome leggibile (es. "Autodromo di Monza") |
| address | text | Indirizzo testuale |
| **location** | geography(Point, 4326) | **Coordinate PostGIS — campo geospaziale** |
| entry_price_cents | integer | Prezzo ingresso in centesimi (0 = gratuito) |
| max_attendees | integer | Capienza massima (NULL = illimitata) |
| cover_image_url | text | URL foto copertina |
| status | text | `draft` / `published` / `cancelled` |
| created_at | timestamptz | Default `now()` |

> ✅ **Beneficio:** prezzo in centesimi (`integer`) evita problemi di arrotondamento dei `float`. Standard di Stripe e di tutti i payment processor seri.

### 5.3 Tabella `attendances`

Iscrizione di un utente come visitatore.

| Campo | Tipo | Descrizione |
|---|---|---|
| **id** | uuid | Primary key |
| raduno_id | uuid | FK a `raduni.id` ON DELETE CASCADE |
| user_id | uuid | FK a `profiles.id` |
| created_at | timestamptz | Default `now()` |
| | | UNIQUE(raduno_id, user_id) |

### 5.4 Tabella `auto`

Garage personale dell'utente.

| Campo | Tipo | Descrizione |
|---|---|---|
| **id** | uuid | Primary key |
| owner_id | uuid | FK a `profiles.id` |
| make | text | Marca (es. "Alfa Romeo") |
| model | text | Modello (es. "Giulia GTAm") |
| year | integer | Anno di immatricolazione |
| description | text | Note del proprietario |
| photo_urls | text[] | Array di URL foto (Supabase Storage) |
| created_at | timestamptz | Default `now()` |

### 5.5 Tabella `auto_exhibitions`

Registrazione di un'auto come esposta a uno specifico raduno.

| Campo | Tipo | Descrizione |
|---|---|---|
| **id** | uuid | Primary key |
| raduno_id | uuid | FK a `raduni.id` ON DELETE CASCADE |
| auto_id | uuid | FK a `auto.id` ON DELETE CASCADE |
| status | text | `pending` / `approved` / `rejected` |
| created_at | timestamptz | Default `now()` |
| | | UNIQUE(raduno_id, auto_id) |

> ⚠️ **Nota Importante:** lo status `approved/rejected` permette all'organizzatore del raduno di accettare/rifiutare l'esposizione delle auto. Per l'MVP puoi lasciarlo sempre `approved` di default e gestire la moderazione in fase 5.

### 5.6 Indici critici

```sql
-- Indice geospaziale (GIST) sul campo location
CREATE INDEX idx_raduni_location ON raduni USING GIST(location);

-- Indice su date per filtri "raduni futuri"
CREATE INDEX idx_raduni_start_at ON raduni(start_at);

-- Indici FK per join rapidi
CREATE INDEX idx_attendances_raduno ON attendances(raduno_id);
CREATE INDEX idx_auto_owner ON auto(owner_id);
```

> ✅ **Beneficio:** l'indice GIST sul campo `location` rende la query "raduni nel raggio di 50km" O(log n) invece che O(n). Su 100k raduni, la differenza è 5ms vs 5 secondi.

---

## 6. Row Level Security (RLS)

Supabase usa le RLS di Postgres per autorizzare le operazioni a livello di riga. **Senza RLS configurate, qualsiasi utente potrebbe leggere/modificare qualsiasi dato.** È il rischio di sicurezza #1 con Supabase.

### 6.1 Policy `raduni`

```sql
-- Tutti possono leggere raduni 'published'
CREATE POLICY "raduni_select_public" ON raduni
  FOR SELECT USING (status = 'published');

-- Solo l'organizzatore può vedere i propri 'draft'
CREATE POLICY "raduni_select_own_drafts" ON raduni
  FOR SELECT USING (auth.uid() = organizer_id);

-- Solo utenti autenticati possono creare
CREATE POLICY "raduni_insert" ON raduni
  FOR INSERT WITH CHECK (auth.uid() = organizer_id);

-- Solo l'organizzatore può modificare/cancellare il proprio raduno
CREATE POLICY "raduni_update_own" ON raduni
  FOR UPDATE USING (auth.uid() = organizer_id);

CREATE POLICY "raduni_delete_own" ON raduni
  FOR DELETE USING (auth.uid() = organizer_id);
```

### 6.2 Policy `auto`

```sql
-- Le auto sono visibili a tutti (per esibirle nei raduni)
CREATE POLICY "auto_select_all" ON auto FOR SELECT USING (true);

-- Solo il proprietario può creare/modificare/cancellare
CREATE POLICY "auto_insert" ON auto
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "auto_update_own" ON auto
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "auto_delete_own" ON auto
  FOR DELETE USING (auth.uid() = owner_id);
```

### 6.3 Checklist RLS

- [ ] RLS abilitata su **ogni** tabella applicativa (non solo policy: bisogna fare `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`)
- [ ] Test manuale da SQL Editor con utente "anon" (deve essere bloccato)
- [ ] Test con utente autenticato che cerca di modificare risorsa altrui (deve essere bloccato)

---

## 7. Query Geospaziale "Raduni Vicini"

### 7.1 Il problema

Dato il punto GPS dell'utente `(lat, lng)`, restituire i raduni `published`, futuri, entro N km, ordinati per distanza.

### 7.2 La soluzione: RPC PostGIS

Crea una funzione PostgreSQL chiamabile da Supabase come RPC:

```sql
CREATE OR REPLACE FUNCTION raduni_nearby(
  user_lat double precision,
  user_lng double precision,
  radius_km double precision DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  title text,
  start_at timestamptz,
  location_name text,
  cover_image_url text,
  entry_price_cents integer,
  distance_km double precision
)
LANGUAGE sql STABLE AS $$
  SELECT
    r.id,
    r.title,
    r.start_at,
    r.location_name,
    r.cover_image_url,
    r.entry_price_cents,
    ST_Distance(
      r.location,
      ST_MakePoint(user_lng, user_lat)::geography
    ) / 1000 AS distance_km
  FROM raduni r
  WHERE r.status = 'published'
    AND r.start_at > now()
    AND ST_DWithin(
      r.location,
      ST_MakePoint(user_lng, user_lat)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC;
$$;
```

**Punti chiave del pattern:**

- `ST_DWithin` usa l'indice GIST → veloce anche su milioni di righe
- Il tipo `geography` interpreta le distanze in **metri** (per questo `radius_km * 1000`)
- **Attenzione:** PostGIS vuole i punti in ordine `(longitude, latitude)`, non viceversa. Errore classico
- `STABLE` permette al planner di cachare il risultato in un singolo statement

### 7.3 Chiamata da Flutter

```dart
final response = await supabase.rpc('raduni_nearby', params: {
  'user_lat': userPosition.latitude,
  'user_lng': userPosition.longitude,
  'radius_km': 50,
});
```

---

## 8. Flusso Autenticazione

Supabase Auth supporta email/password, magic link, OAuth (Google, Apple). Per l'MVP:

1. **Email + password** come default (più rapido da testare in dev)
2. **Sign in with Apple** richiesto da App Store se hai altri provider OAuth (regola Apple, da sapere prima della submission)
3. **Sign in with Google** opzionale per Android, ma molto richiesto

### Flusso a runtime

1. App parte → controlla `Supabase.instance.client.auth.currentSession`
2. Se sessione valida → vai a `/home`
3. Se no → vai a `/login`
4. Listener su `onAuthStateChange` redirige automaticamente in caso di logout/scadenza token

---

## 9. Flusso Mappa e Geolocalizzazione

### 9.1 Permessi

`geolocator` gestisce i permessi runtime. Pattern:

```dart
// pseudo-code
Future<Position> getUserPosition() async {
  // 1. Servizi attivi?
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationServiceDisabledException();
  }

  // 2. Permesso concesso?
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) {
      throw const PermissionDeniedException();
    }
  }
  if (perm == LocationPermission.deniedForever) {
    throw const PermissionDeniedForeverException();
  }

  // 3. Ottieni posizione (con timeout)
  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.medium,
    timeLimit: const Duration(seconds: 10),
  );
}
```

> ⚠️ **Nota Importante:** la prima volta che un utente apre la mappa, il dialog di permessi compare. Se rifiuta, devi mostrare uno stato di fallback (es. mappa centrata su Roma) con CTA "Abilita posizione nelle Impostazioni". Mai bloccare l'app.

### 9.2 UI Mappa

Pattern raccomandato:

- **FlutterMap** centrato sulla posizione utente (zoom 11, ~50km visibili)
- **MarkerLayer** con un marker per ogni raduno restituito da `raduni_nearby`
- **Tap su marker** → bottom sheet con info raduno e bottone "Vedi dettagli"
- **Pulsante "ricarica"** in basso a destra: ricarica i raduni visibili usando il bbox della mappa corrente

---

## 10. Storage Foto (Supabase Storage)

### 10.1 Bucket da creare

| Bucket | Pubblico? | Uso |
|---|---|---|
| `avatars` | sì (read pubblico) | Foto profilo |
| `raduni-covers` | sì | Copertine raduni |
| `auto-photos` | sì | Foto auto del garage |

### 10.2 Upload pattern

```dart
// pseudo-code
final file = await ImagePicker().pickImage(source: ImageSource.gallery);
if (file == null) return;

final bytes = await file.readAsBytes();
final fileName = '${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';

await supabase.storage.from('auto-photos').uploadBinary(
  fileName,
  bytes,
  fileOptions: const FileOptions(contentType: 'image/jpeg'),
);

final publicUrl = supabase.storage
  .from('auto-photos')
  .getPublicUrl(fileName);
```

> ✅ **Beneficio:** prefissare con `userId` nel path permette di applicare RLS sullo storage tipo "puoi cancellare solo file dentro il tuo prefisso". Senza prefisso, Mario potrebbe sovrascrivere la foto di Luigi.

### 10.3 Compressione lato client

Una foto da iPhone è ~3MB. Su 100 raduni × 5 auto × 5 foto = 7.5GB di banda solo per scrollare la home. **Sempre comprimere prima di upload** (target: lato lungo 1600px, JPEG quality 80, ~250KB).

---

## 11. Routing con go_router

Struttura rotte minima:

```
/                        → splash, redirect a /login o /home
/login                   → schermata login
/signup                  → registrazione
/home                    → tab bar (raduni, mappa, garage, profilo)
  /home/raduni           → lista raduni vicini
  /home/raduni/:id       → dettaglio raduno
  /home/raduni/create    → creazione raduno (organizzatore)
  /home/map              → mappa interattiva
  /home/garage           → mio garage
  /home/garage/:autoId   → dettaglio auto
  /home/garage/add       → aggiungi auto
  /home/profile          → profilo utente
```

> ✅ **Beneficio:** con go_router il deep link `raduni-app://home/raduni/abc123` apre direttamente il raduno. Utile per link condivisi via WhatsApp.

---

**Prossimo documento:** `02-FASI-IMPLEMENTAZIONE.md` — roadmap implementativa, stime, rischi.
