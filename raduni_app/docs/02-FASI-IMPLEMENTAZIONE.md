# RADUNI APP — FASI DI IMPLEMENTAZIONE

**Documento:** 02 di 03 — Roadmap, stime e rischi
**Versione:** 1.0
**Data:** 7 Maggio 2026
**Target:** Sviluppatore Flutter, conoscenza dell'architettura definita nel documento 01

> **Obiettivo:** Definire l'ordine di implementazione delle feature, le stime in giornate, i deliverable di ogni fase e i rischi tecnici associati.

---

## Indice

1. Riepilogo Stime
2. Fase 1 — Bootstrap & Auth
3. Fase 2 — CRUD Raduni
4. Fase 3 — Mappa Interattiva
5. Fase 4 — Garage & Esposizioni Auto
6. Fase 5 — Polish, Notifiche, Profilo
7. Fase 6 (futura) — Pagamenti
8. Rischi e Mitigazioni
9. Considerazioni sulle Prestazioni
10. Raccomandazione Go/No-Go

---

## 1. Riepilogo Stime

| Fase | Descrizione | Stima |
|---|---|---|
| 1 | Bootstrap & Auth | 3-4 giorni |
| 2 | CRUD Raduni | 4-5 giorni |
| 3 | Mappa Interattiva | 3-4 giorni |
| 4 | Garage & Esposizioni | 4-5 giorni |
| 5 | Polish, Notifiche, Profilo | 3-4 giorni |
| **Totale MVP** | | **17-22 giorni lavorativi** |
| 6 (futura) | Pagamenti Stripe | +5-7 giorni |

> ⚠️ **Nota Importante:** le stime presuppongono uno sviluppatore con esperienza Flutter base e conoscenza SQL. Se è il **primo progetto Flutter in assoluto**, aggiungi un 30-40% per la curva d'apprendimento (target realistico: 25-30 giorni per l'MVP).

---

## 2. Fase 1 — Bootstrap & Auth (3-4 giorni)

### Deliverable

- Progetto Flutter creato secondo `00-SETUP-MACBOOK.md`
- Struttura cartelle feature-first creata (vedi doc 01 sezione 3)
- Tema Material 3 di base con colori brand
- Schema DB Supabase completo (tabelle + RLS + indici + funzione `raduni_nearby`)
- Schermata Login con email/password
- Schermata Signup con creazione automatica del record `profiles`
- Persistenza sessione (al riavvio dell'app, l'utente resta loggato)
- Logout funzionante
- Routing con go_router e redirect basato su sessione

### Pattern implementativo

**Inizializzazione Supabase in `main.dart`:**

```dart
// Pattern: init Supabase prima di runApp
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xxxxx.supabase.co',
    anonKey: 'eyJ...',  // anon key, mai service_role
  );

  runApp(const ProviderScope(child: RaduniApp()));
}
```

**Trigger auto-creazione profilo:** quando un utente fa signup, devi avere una riga corrispondente in `profiles`. Due strade:

1. **Dal client:** dopo signup, fai INSERT su `profiles`. Rischio: se l'app crasha tra signup e insert, l'utente esiste in `auth.users` ma non in `profiles`
2. **Trigger Postgres** (consigliato): più robusto

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    'user_' || substr(NEW.id::text, 1, 8),  -- placeholder, l'utente lo cambierà
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Utente')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

> ✅ **Beneficio:** atomicità garantita lato DB. Anche se l'app crasha, la riga `profiles` viene creata nella stessa transazione.

### Testing & Validazione

- [ ] Signup → arriva email di conferma → click sul link → utente loggato
- [ ] Login con credenziali errate → messaggio chiaro all'utente
- [ ] Killare l'app e riaprirla → utente resta loggato
- [ ] RLS testata: query SELECT da SQL Editor con `auth.uid() = NULL` deve restituire solo righe pubbliche

---

## 3. Fase 2 — CRUD Raduni (4-5 giorni)

### Deliverable

- Schermata "Crea raduno" con form (titolo, descrizione, data/ora, indirizzo, prezzo)
- Geocoding indirizzo → lat/lng (vedi sotto: scelta tecnica)
- Upload foto copertina su Supabase Storage
- Schermata "Lista raduni vicini" (placeholder, senza GPS reale, lista globale)
- Schermata "Dettaglio raduno" con tutte le info
- Modifica/cancellazione raduno (solo se `auth.uid() == organizer_id`)
- Real-time updates: se aggiungi un raduno, compare nella lista degli altri device senza refresh

### Decisione tecnica: geocoding

L'utente scrive un indirizzo testuale, dobbiamo ottenere `(lat, lng)`.

**Opzioni:**

1. **Nominatim** (OpenStreetMap, gratis): ok per dev, ma **terms of use vietano uso commerciale ad alto volume**
2. **Mapbox Geocoding API:** 100k chiamate/mese gratis, qualità ottima
3. **Google Geocoding API:** $5/1000 chiamate, qualità eccellente
4. **Inserimento manuale del pin sulla mappa** dall'organizzatore: zero costi, UX leggermente più lenta

**Decisione raccomandata MVP:** **opzione 4** (pin sulla mappa). Costi zero, niente dipendenza da terzi, e in pratica un organizzatore di raduno conosce già il punto esatto.

In fase 5 puoi aggiungere geocoding Mapbox come "scorciatoia" opzionale.

### Inserimento del campo `location` PostGIS da Flutter

```dart
// Pattern: insert con geography point
await supabase.from('raduni').insert({
  'organizer_id': supabase.auth.currentUser!.id,
  'title': titolo,
  'start_at': startDate.toIso8601String(),
  'location_name': locationName,
  // PostGIS accetta WKT (Well-Known Text)
  'location': 'POINT($lng $lat)',
  'entry_price_cents': prezzoEuro * 100,
  'status': 'published',
});
```

> ⚠️ **Nota Importante:** WKT vuole `POINT(longitudine latitudine)` con lo spazio in mezzo, **longitudine prima**. Sbagliare l'ordine è un bug subdolo: l'INSERT non fallisce, ma il raduno finisce dall'altra parte del mondo.

### Real-time updates

Supabase emette eventi su INSERT/UPDATE/DELETE. Pattern Riverpod:

```dart
@riverpod
Stream<List<Raduno>> raduniListStream(RaduniListStreamRef ref) {
  return Supabase.instance.client
    .from('raduni')
    .stream(primaryKey: ['id'])
    .eq('status', 'published')
    .order('start_at')
    .map((rows) => rows.map(Raduno.fromJson).toList());
}
```

---

## 4. Fase 3 — Mappa Interattiva (3-4 giorni)

### Deliverable

- Schermata mappa con `flutter_map` + tile OSM
- Geolocalizzazione utente con `geolocator` (incluso pattern permessi del doc 01 sezione 9.1)
- Marker per ogni raduno entro 50km (chiamata RPC `raduni_nearby`)
- Tap su marker → bottom sheet con info essenziali + CTA "Dettagli"
- Pulsante "Ricentra su di me"
- Slider raggio (10 / 25 / 50 / 100 km)
- Stato loading mentre la query è in corso
- Stato errore se permessi rifiutati (con CTA "Apri Impostazioni")

### Pattern implementativo: aggiornamento marker al move della mappa

Strategia: **non** ricaricare ad ogni pixel di pan, ma con debounce.

```dart
// Pattern: debounce dei movimenti mappa per evitare spam di query
Timer? _debounceTimer;

void onMapMoved(MapPosition pos) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    ref.invalidate(raduniNearbyProvider(
      lat: pos.center!.latitude,
      lng: pos.center!.longitude,
    ));
  });
}
```

> ✅ **Beneficio:** se l'utente scorre la mappa rapidamente da Roma a Milano, fai una sola query a destinazione invece di 50 lungo il tragitto.

### Stato fallback se GPS negato

Se l'utente nega i permessi, **non bloccare la mappa**. Mostra:

- Mappa centrata su un punto di default (es. centro Italia, lat 42.5, lng 12.5, zoom 6)
- Banner in alto: "Abilita la posizione per vedere i raduni vicini" con tap → apre Settings

---

## 5. Fase 4 — Garage & Esposizioni Auto (4-5 giorni)

### Deliverable

- Schermata "Mio garage": lista delle proprie auto
- Schermata "Aggiungi auto": form con make, model, year, descrizione, foto multiple
- Upload multiplo foto su `auto-photos` bucket con compressione lato client
- Schermata "Dettaglio auto" con galleria foto
- Cancellazione auto (con conferma e cleanup foto storage)
- Sul dettaglio raduno: bottone "Esponi una mia auto" → modal con lista auto utente
- Tabella `auto_exhibitions` popolata correttamente
- Lista delle auto esposte mostrata sul dettaglio raduno (con foto, marca, modello, owner)

### Pattern implementativo: compressione foto

```dart
// Pattern: ridurre dimensione prima di upload
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Uint8List> compressForUpload(File originalFile) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    originalFile.absolute.path,
    minWidth: 1600,    // lato lungo target
    minHeight: 1600,
    quality: 80,        // sweet spot dimensione/qualità
    format: CompressFormat.jpeg,
  );
  return compressed!;
}
```

Aggiungi al `pubspec.yaml`:

```yaml
flutter_image_compress: ^2.3.0
```

### Cleanup foto al delete

Quando si cancella un'auto, le foto su Storage **non si cancellano automaticamente**. Pattern:

```dart
// Pattern: delete cascade lato client
Future<void> deleteAuto(String autoId) async {
  // 1. Recupera URL foto
  final auto = await fetchAuto(autoId);

  // 2. Estrai i path dai public URL
  final paths = auto.photoUrls
    .map((url) => extractStoragePath(url))
    .toList();

  // 3. Cancella file da Storage
  if (paths.isNotEmpty) {
    await supabase.storage.from('auto-photos').remove(paths);
  }

  // 4. Cancella riga DB (cascade su auto_exhibitions via FK)
  await supabase.from('auto').delete().eq('id', autoId);
}
```

> ⚠️ **Nota Importante:** se il delete riga DB fallisce dopo il delete Storage, hai inconsistenza. In produzione si risolve con un job di cleanup o con un trigger Postgres che pubblica un evento. Per l'MVP accetta il piccolo rischio e logga gli errori.

---

## 6. Fase 5 — Polish, Notifiche, Profilo (3-4 giorni)

### Deliverable

- Schermata "Profilo": modifica username, display_name, avatar
- Lista "I miei raduni" (organizzati / a cui partecipo)
- Pull-to-refresh su tutte le liste
- Empty states curati (illustrazioni o icone + testo guida)
- Skeleton loaders al posto degli spinner per UX migliore
- Push notification base con FCM (opzionale per MVP)
- Onboarding 3 schermate al primo avvio
- Icona app + splash screen brandizzati
- Build di rilascio testata su device fisico

### Push notifications (opzionale MVP)

Setup FCM richiede:

- Account Firebase (gratuito)
- File `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)
- APNs key da Apple Developer (per iOS)
- Pacchetto `firebase_messaging`

**Use case minimo utile:** notifica quando qualcuno si iscrive al tuo raduno o espone un'auto.

> ⚠️ **Fase Opzionale:** se rischi di sforare i tempi, le push si possono posticipare al post-MVP. La app è perfettamente usabile senza.

### Build di rilascio

```bash
# iOS
flutter build ios --release
# poi archive da Xcode → Distribute App → TestFlight

# Android
flutter build appbundle --release
# upload su Play Console → Internal Testing
```

---

## 7. Fase 6 (futura) — Pagamenti (+5-7 giorni)

Quando vorrai integrare i pagamenti per l'ingresso ai raduni:

### Stack consigliato

- **Stripe** come payment processor (`flutter_stripe` ufficiale)
- **Edge Function Supabase** per creare PaymentIntent server-side (non puoi mettere la secret key di Stripe nell'app)
- **Webhook Stripe** che chiama un'altra Edge Function per aggiornare lo stato pagamento sul raduno

### Schema aggiuntivo

```sql
ALTER TABLE attendances ADD COLUMN payment_status text DEFAULT 'free';
ALTER TABLE attendances ADD COLUMN stripe_payment_intent_id text;
ALTER TABLE attendances ADD COLUMN paid_at timestamptz;
```

### Considerazioni legali

> ⚠️ **Nota Importante:** vendere biglietti per eventi può richiedere partita IVA, fatturazione elettronica, e in alcuni casi (eventi pubblici grandi) autorizzazioni specifiche (SIAE, sicurezza). Prima di abilitare i pagamenti reali, **consulta un commercialista**. Tecnicamente Stripe è 1 settimana, normativamente è il punto delicato.

---

## 8. Rischi e Mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Sviluppatore alle prime armi con Flutter sottostima la curva | **Alto** — slittamento date | Aggiungi buffer 30-40% sulle stime; fai prima un side-project di pratica con un'app to-do; segui il primo modulo del corso ufficiale Flutter |
| RLS dimenticate o configurate male | **Alto** — data leak, qualunque utente legge tutti i dati | Checklist obbligatoria fine Fase 1; test manuali con `auth.uid() IS NULL`; Supabase ha un linter che evidenzia tabelle senza RLS |
| Inversione `lng/lat` in PostGIS | **Medio** — raduni in posizioni sbagliate | Wrappa la creazione del WKT in una funzione helper unica nel codice Dart, mai inline |
| Permessi GPS rifiutati dall'utente | **Medio** — feature mappa inutilizzabile | Stato fallback con mappa centrata su default, banner non bloccante che invita ad abilitare |
| Foto pesanti saturano banda e quota Storage | **Medio** — costi e UX lenta | Compressione obbligatoria lato client (sezione 4); imposta quota allarme su Supabase a 80% del piano |
| Apple rifiuta l'app per "Sign in with Apple" mancante | **Alto** — blocco go-live iOS | Implementare Sign in with Apple appena aggiungi qualsiasi altro OAuth (Google etc.). Se solo email/password, è opzionale |
| Vendor lock-in Supabase se cresce molto | **Basso** — fastidioso ma gestibile | Supabase è Postgres puro; in caso si migra il DB in 1-2 giorni. Solo Auth e Storage richiedono porting |
| Costi Supabase oltre tier free | **Basso** | Tier free copre 500MB DB e 1GB storage. Allarmi su uso |
| Nominatim/OSM banna l'IP per troppo traffico | **Medio** — geocoding non funziona | Già evitato scegliendo "pin manuale" (sezione 3) |

---

## 9. Considerazioni sulle Prestazioni

### Hotspot 1: query `raduni_nearby` su grandi volumi

**Ottimizzazione:**

- Indice GIST già configurato (vedi doc 01 sezione 5.6)
- Limita risultati a 100 raduni max nel client (`ORDER BY distance LIMIT 100`)
- Cache lato Riverpod con TTL 60 secondi

**Impatto atteso:** query <50ms anche su 1M di raduni nel DB.

### Hotspot 2: lista raduni con foto copertina

**Ottimizzazione:**

- `cached_network_image` per evitare di scaricare la stessa immagine due volte
- Image transformations Supabase: `?width=400&quality=70` nell'URL → server restituisce versione già ridimensionata
- Lazy load: `ListView.builder` non `ListView`

**Impatto atteso:** scroll fluido a 60fps su iPhone medio anche con 50+ raduni in lista.

### Hotspot 3: caricamento mappa con molti marker

**Ottimizzazione:**

- Limita marker visibili al bounding box della mappa, non al cerchio raggio
- A zoom basso (paese intero), **clusterizza** i marker (`flutter_map_marker_cluster`)
- Marker custom usa `Container` semplice, non widget complessi

**Impatto atteso:** mappa fluida con 200+ marker visibili.

### Hotspot 4: real-time stream lasciato attivo in background

**Ottimizzazione:**

- Stream Riverpod sono auto-dispose: si chiudono quando la UI non li ascolta
- Verifica con DevTools che non ci siano stream "zombie" che continuano a ricevere update

---

## 10. Raccomandazione Go/No-Go

> ✅ **RACCOMANDAZIONE: GO**
>
> Lo stack Flutter + Supabase + flutter_map + Riverpod è **maturo, gratuito al MVP, e dimostrato in produzione** per app simili. La query geospaziale, che era il rischio architetturale principale, è risolta in modo elegante e performante con PostGIS.
>
> **Tempo MVP realistico:** 17-22 giorni per sviluppatore esperto Flutter, 25-30 giorni se è il primo progetto.
>
> **Costi infrastruttura primi 6 mesi:** 0 € (tier free Supabase + OSM).
>
> **Punto critico da non sottovalutare:** le RLS. Sono il singolo aspetto che, se trascurato, espone l'app a problemi seri di sicurezza. Tutto il resto è incrementale.

---

## Checklist Pre-Sviluppo

Prima di iniziare a scrivere codice, verifica:

- [ ] Lette entrambe le sezioni `00-SETUP-MACBOOK.md` (eseguito) e `01-ARCHITETTURA.md` (capito)
- [ ] `flutter doctor` tutto verde
- [ ] Progetto Supabase creato, PostGIS abilitato
- [ ] Tabelle, indici, RLS, funzione `raduni_nearby` create da SQL Editor
- [ ] Trigger `on_auth_user_created` testato (signup di prova → riga in `profiles`)
- [ ] Bucket Storage creati (`avatars`, `raduni-covers`, `auto-photos`)
- [ ] Repository git inizializzato con `.gitignore` per Flutter (`flutter create` lo fa già)
- [ ] File con chiavi API **non** committato (`.env.local` o equivalente in `.gitignore`)

---

**Documenti correlati:**
- `00-SETUP-MACBOOK.md` — installazione ambiente
- `01-ARCHITETTURA.md` — decisioni architetturali e modello dati
