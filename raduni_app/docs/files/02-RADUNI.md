# 02 — RADUNI

> **Subagente:** Raduni (lista, dettaglio, creazione, iscrizioni)
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** `00-BOOTSTRAP.md` + `01-AUTH.md` completati.
> **Output:** Home con dati reali, dettaglio raduno funzionante, creazione raduno funzionante.
> **Stima:** 8-12 ore di lavoro Claude Code

---

## 1. Obiettivo

Questa è la feature **core** dell'app. Tre task in uno:

1. Sostituire `MockData.raduni` nella `HomeScreen` con uno stream Supabase.
2. Trasformare `DetailRadunoScreen` da stub al dettaglio completo (cover + info + partecipanti + iscriviti).
3. Trasformare `CreateRadunoScreen` da stub a form scrollabile funzionante con upload cover.

**File coinvolti:**

| File | Stato attuale | Azione |
|---|---|---|
| `lib/features/home/presentation/home_screen.dart` | ✅ UI fatta, usa `MockData.raduni` | Sostituire mock con `StreamProvider` |
| `lib/features/raduno/presentation/detail_screen.dart` | ❌ Stub (`Center(Text('TODO...'))`) | Implementare full screen secondo `HANDOFF.md` § 5.5 |
| `lib/features/raduno/presentation/create_screen.dart` | ❌ Stub | Form scrollabile + upload cover |
| `lib/shared/widgets/compact_raduno_card.dart` | ✅ Pixel-perfect | Non toccare |
| `lib/shared/mock_data.dart` | ⚠️ In uso da `HomeScreen` | Lasciare per ora, rimuovere a fine progetto |

> ⚠️ **Vincolo:** la `HomeScreen` è già pixel-perfect. Limitati a sostituire la
> riga `final raduni = MockData.raduni;` (o equivalente) con un
> `ref.watch(...)` su un provider asincrono e gestire i 3 stati
> `loading/error/data`. **Non riscrivere la struttura** del `CustomScrollView`.

### Dipendenze da aggiungere al `pubspec.yaml`

Solo per il form Crea (geocoding inverso da pin sulla mappa):

```yaml
  geocoding: ^3.0.0
```

Dopo l'aggiunta:

```bash
cd raduni_app && flutter pub get
```

---

## 2. Modello dati (riferimento)

Da `Car-Meet/01-ARCHITETTURA.md` § 7. Tabella `raduni`:

| Campo | Tipo | Note |
|---|---|---|
| `id` | uuid (PK) | |
| `titolo` | text | |
| `sottotitolo` | text? | |
| `quando` | timestamptz | |
| `luogo` | text | Indirizzo testuale |
| `citta` | text | |
| `lat` | float8 | |
| `lng` | float8 | |
| `geom` | geography(Point, 4326) | Generato da `lat`/`lng`, indicizzato GIST |
| `partecipanti` | int | Default 0, aggiornato da trigger |
| `max_partecipanti` | int | |
| `cover_url` | text | URL Supabase Storage |
| `organizzatore_uid` | uuid (FK profiles) | |
| `tag` | text[] | |
| `gratuito` | boolean | Default true |
| `prezzo` | numeric? | |
| `descrizione` | text? | |
| `created_at` | timestamptz | |

Tabella `iscrizioni`:

| Campo | Tipo | Note |
|---|---|---|
| `raduno_id` | uuid (FK raduni) | PK composta |
| `utente_uid` | uuid (FK profiles) | PK composta |
| `auto_id` | uuid (FK auto)? | Auto esposta, opzionale |
| `stato` | text | "confermata" / "in_attesa" |
| `joined_at` | timestamptz | |

Bucket Storage: `raduni-covers` (pubblico).

> ⚠️ **Nota campo `iscritto`:** il modello `Raduno` Dart ha già un campo
> `iscritto: bool`. Lato DB **non esiste** una colonna così — è un campo
> derivato che il client riempie con una `select` aggiuntiva su `iscrizioni`
> per l'utente loggato (vedi §4 nel metodo `_radunoFromRow`).

---

## 3. Architettura della feature

```
features/
├── home/
│   ├── data/
│   │   └── raduni_repository.dart          # Da creare
│   ├── application/
│   │   └── raduni_providers.dart           # Da creare
│   └── presentation/
│       └── home_screen.dart                # Già fatta, da connettere
└── raduno/
    ├── application/
    │   └── raduno_detail_providers.dart    # Da creare
    └── presentation/
        ├── detail_screen.dart              # Da costruire da zero
        ├── create_screen.dart              # Da costruire da zero
        └── widgets/                        # Da creare
            ├── partecipanti_stack.dart
            ├── auto_esposte_grid.dart
            └── iscrizione_button.dart
```

```bash
mkdir -p raduni_app/lib/features/home/data
mkdir -p raduni_app/lib/features/home/application
mkdir -p raduni_app/lib/features/raduno/application
mkdir -p raduni_app/lib/features/raduno/presentation/widgets
```

> ✅ **Beneficio:** il `RaduniRepository` è in `home/data/` perché la home è il
> consumatore principale, ma è **condiviso** con `detail_screen` e
> `map_screen`. Un solo repository per i raduni in tutta l'app.

---

## 4. Step 1 — `RaduniRepository`

`raduni_app/lib/features/home/data/raduni_repository.dart`:

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/guard.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/raduno.dart';

class RaduniRepository {
  final sb.SupabaseClient _client;
  RaduniRepository(this._client);

  /// Stream dei raduni vicini all'utente, ordinati per distanza.
  /// Usa la function PostgreSQL `raduni_nearby(lat, lng, raggio_km)`
  /// definita in 01-ARCHITETTURA.md § 8.3.
  ///
  /// Pattern: refresh periodico ogni 30s + initial fetch immediato.
  /// Per realtime "vero" si passerà a Supabase channel in fase 6.
  Stream<List<Raduno>> streamNearby({
    required double lat,
    required double lng,
    double raggioKm = 50,
  }) async* {
    yield await _fetchNearby(lat: lat, lng: lng, raggioKm: raggioKm);
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => _fetchNearby(lat: lat, lng: lng, raggioKm: raggioKm));
  }

  Future<List<Raduno>> _fetchNearby({
    required double lat,
    required double lng,
    required double raggioKm,
  }) {
    return guardSupabase(() async {
      final rows = await _client.rpc('raduni_nearby', params: {
        'lat': lat,
        'lng': lng,
        'raggio_km': raggioKm,
      });
      return (rows as List)
          .map((r) => radunoFromRow(r as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Raduno> getById(String id) {
    return guardSupabase(() async {
      final row = await _client
          .from('raduni')
          .select('*, organizzatore:profiles!organizzatore_uid(nome, avatar_url)')
          .eq('id', id)
          .single();
      return radunoFromRow(row);
    });
  }

  Future<String> create({
    required String titolo,
    String? sottotitolo,
    required DateTime quando,
    required String luogo,
    required String citta,
    required double lat,
    required double lng,
    required int maxPartecipanti,
    required List<String> tag,
    required bool gratuito,
    double? prezzo,
    String? descrizione,
    File? coverFile,
  }) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;

      // 1. Upload cover (se presente) PRIMA di creare la riga.
      String coverUrl = _defaultCoverUrl;
      if (coverFile != null) {
        coverUrl = await _uploadCover(coverFile, uid);
      }

      // 2. Insert raduno
      final inserted = await _client
          .from('raduni')
          .insert({
            'titolo': titolo,
            'sottotitolo': sottotitolo,
            'quando': quando.toUtc().toIso8601String(),
            'luogo': luogo,
            'citta': citta,
            'lat': lat,
            'lng': lng,
            'max_partecipanti': maxPartecipanti,
            'cover_url': coverUrl,
            'organizzatore_uid': uid,
            'tag': tag,
            'gratuito': gratuito,
            'prezzo': prezzo,
            'descrizione': descrizione,
          })
          .select('id')
          .single();

      return inserted['id'] as String;
    });
  }

  Future<void> iscriviti(String radunoId, {String? autoId}) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;
      await _client.from('iscrizioni').insert({
        'raduno_id': radunoId,
        'utente_uid': uid,
        'auto_id': autoId,
        'stato': 'confermata',
      });
    });
  }

  Future<void> disiscriviti(String radunoId) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;
      await _client
          .from('iscrizioni')
          .delete()
          .eq('raduno_id', radunoId)
          .eq('utente_uid', uid);
    });
  }

  Future<bool> isIscritto(String radunoId) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;
      final res = await _client
          .from('iscrizioni')
          .select('utente_uid')
          .eq('raduno_id', radunoId)
          .eq('utente_uid', uid)
          .maybeSingle();
      return res != null;
    });
  }

  Future<String> _uploadCover(File file, String uid) async {
    final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from('raduni-covers')
        .upload(fileName, file, fileOptions: const sb.FileOptions(upsert: true));
    return _client.storage.from('raduni-covers').getPublicUrl(fileName);
  }

  static const _defaultCoverUrl =
      'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900';

  /// Pubblico (non _-prefisso) perché è riusato da subagenti Profilo
  /// per costruire la lista "I miei raduni" dalle iscrizioni.
  Raduno radunoFromRow(Map<String, dynamic> row) {
    return Raduno(
      id: row['id'] as String,
      titolo: row['titolo'] as String,
      sottotitolo: row['sottotitolo'] as String?,
      quando: DateTime.parse(row['quando'] as String).toLocal(),
      luogo: row['luogo'] as String,
      citta: row['citta'] as String,
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      distanzaKm: (row['distanza_km'] as num?)?.toDouble() ?? 0,
      partecipanti: row['partecipanti'] as int? ?? 0,
      maxPartecipanti: row['max_partecipanti'] as int? ?? 0,
      coverUrl: row['cover_url'] as String? ?? _defaultCoverUrl,
      organizzatore: row['organizzatore']?['nome'] as String? ?? 'Sconosciuto',
      tag: ((row['tag'] as List?) ?? []).cast<String>(),
      iscritto: row['iscritto'] as bool? ?? false,
      gratuito: row['gratuito'] as bool? ?? true,
      prezzo: (row['prezzo'] as num?)?.toDouble(),
    );
  }
}

final raduniRepositoryProvider = Provider<RaduniRepository>((ref) {
  return RaduniRepository(ref.watch(supabaseClientProvider));
});
```

> ⚠️ **Nota Importante:** il pattern `async*` con `yield` iniziale + periodic
> fa polling ogni 30s. Per la home va bene (con pull-to-refresh manuale). Per
> la mappa con marker live useremo Realtime channel — vedi `03-MAPPA.md`.

---

## 5. Step 2 — Provider Home

`raduni_app/lib/features/home/application/raduni_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/raduno.dart';
import '../data/raduni_repository.dart';

/// Posizione corrente dell'utente.
/// Default: Milano se l'utente non ha ancora dato permessi geolocator.
final userPositionProvider = StateProvider<({double lat, double lng})>((ref) {
  return (lat: 45.4642, lng: 9.1900); // Milano
});

/// Stream dei raduni vicini, dipende da userPosition.
final raduniNearbyProvider = StreamProvider<List<Raduno>>((ref) {
  final pos = ref.watch(userPositionProvider);
  return ref.watch(raduniRepositoryProvider).streamNearby(
        lat: pos.lat,
        lng: pos.lng,
        raggioKm: 50,
      );
});

/// Filtro corrente sui chip della home.
enum RaduniFilter { tutti, settimana, storiche, sportive, trackday }

final raduniFilterProvider =
    StateProvider<RaduniFilter>((ref) => RaduniFilter.tutti);

/// Lista filtrata derivata da raduniNearbyProvider + filtro.
final raduniFiltratiProvider = Provider<AsyncValue<List<Raduno>>>((ref) {
  final filter = ref.watch(raduniFilterProvider);
  final raduni = ref.watch(raduniNearbyProvider);

  return raduni.whenData((list) {
    switch (filter) {
      case RaduniFilter.tutti:
        return list;
      case RaduniFilter.settimana:
        final weekFromNow = DateTime.now().add(const Duration(days: 7));
        return list.where((r) => r.quando.isBefore(weekFromNow)).toList();
      case RaduniFilter.storiche:
        return list.where((r) => r.tag.contains('Storiche')).toList();
      case RaduniFilter.sportive:
        return list.where((r) => r.tag.contains('Sportive')).toList();
      case RaduniFilter.trackday:
        return list.where((r) => r.tag.contains('Pista')).toList();
    }
  });
});
```

---

## 6. Step 3 — Connettere `HomeScreen`

Apri `raduni_app/lib/features/home/presentation/home_screen.dart`. **Cambia
solo**:

1. La classe da `StatelessWidget` a `ConsumerWidget`.
2. La riga `final raduni = MockData.raduni;` → `final raduniAsync = ref.watch(raduniFiltratiProvider);`.
3. Lo Sliver della lista deve gestire i 3 stati.
4. I filter chip devono leggere/scrivere su `raduniFilterProvider`.

```dart
// Sliver lista raduni — sostituisce SliverList.separated attuale
SliverPadding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
  sliver: raduniAsync.when(
    loading: () => const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
    ),
    error: (e, _) => SliverToBoxAdapter(
      child: _ErrorState(
        message: e is AppException ? e.message : 'Errore caricamento raduni',
        onRetry: () => ref.invalidate(raduniNearbyProvider),
      ),
    ),
    data: (raduni) {
      if (raduni.isEmpty) {
        return const SliverToBoxAdapter(child: _EmptyState());
      }
      return SliverList.separated(
        itemCount: raduni.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => CompactRadunoCard(
          raduno: raduni[i],
          onTap: () => context.push('/raduno/${raduni[i].id}'),
        ),
      );
    },
  ),
),
```

**Aggiungi pull-to-refresh** wrappando il `CustomScrollView` in un
`RefreshIndicator`:

```dart
RefreshIndicator(
  color: AppColors.accent,
  onRefresh: () async => ref.invalidate(raduniNearbyProvider),
  child: CustomScrollView(...),
)
```

**FilterChips:** se il widget esistente è uno `_FilterChip` con bool
`selected`, trasformalo in stateful o passa un callback per leggere/scrivere
`raduniFilterProvider`. Usa:

```dart
ref.read(raduniFilterProvider.notifier).state = RaduniFilter.xxx;
```

> ✋ **Vincolo:** i chip esistenti hanno styling pixel-perfect. Mantieni
> esattamente le stesse `BorderRadius`, gli stessi colori e padding. Cambi
> solo la sorgente del `selected: bool`.

---

## 7. Step 4 — `DetailRadunoScreen`

Sostituisci completamente lo stub. **Spec:** `raduni_app/HANDOFF.md` § 5.5.

Layout target (riassunto):

```
┌─────────────────────────────────┐
│ SliverAppBar expanded            │
│  ┌──────────────────────────┐   │
│  │   Cover full-bleed (280h)│   │
│  │   con gradiente nero in  │   │
│  │   basso per leggibilità  │   │
│  └──────────────────────────┘   │
├─────────────────────────────────┤
│ Titolo (28pt, w600, ink)        │
│ data, ore · città               │
├─────────────────────────────────┤
│ ⊙ Avatar  Org. Name      [Segui]│
├─────────────────────────────────┤
│ QUANDO                          │
│ Mercoledì 15 maggio · 09:30     │
├─────────────────────────────────┤
│ DOVE                            │
│ Mini-mappa 160h + indirizzo +   │
│ "Apri in Maps"                  │
├─────────────────────────────────┤
│ CHI PARTECIPA                   │
│ ◯◯◯◯◯ +47 altri                 │
├─────────────────────────────────┤
│ AUTO ESPOSTE                    │
│ Griglia 2 col card auto         │
├─────────────────────────────────┤
│ DESCRIZIONE                     │
│ Testo lungo                     │
└─────────────────────────────────┘
       (CTA fissa in basso)
[ Iscriviti gratis  → ]
```

**Pattern per la CTA fissa:** `Stack` con `Positioned.fill` per il
`CustomScrollView` e `Positioned(bottom: 0, left: 0, right: 0)` per il
bottone con padding
`EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12)`.

**Provider necessari** in `raduno_detail_providers.dart`:

```dart
final radunoDetailProvider = FutureProvider.family<Raduno, String>((ref, id) {
  return ref.watch(raduniRepositoryProvider).getById(id);
});

final isIscrittoProvider = FutureProvider.family<bool, String>((ref, id) {
  return ref.watch(raduniRepositoryProvider).isIscritto(id);
});
```

**Sezioni da implementare come widget separati** in
`lib/features/raduno/presentation/widgets/`:

- `_SectionHeader(title)` — titolo sezione mono uppercase 11pt
- `_QuandoSection(raduno)`
- `_DoveSection(raduno)` — mini-mappa con `flutter_map` (singolo marker, non interattiva)
- `_PartecipantiStack(uids)` — fetch lista partecipanti, mostra prime 5 avatar + "+N altri"
- `_AutoEsposteGrid(radunoId)` — fetch da `iscrizioni` con join `auto`
- `_IscrizioneCta(radunoId, gratuito, prezzo)`

> ⚠️ **Nota Importante:** non implementare la mini-mappa con tutti i controlli
> interattivi. È **solo decorativa**. Imposta:
> ```dart
> interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)
> ```

> ✋ Se la sezione "Auto esposte" diventa complessa, **fermati** dopo aver
> implementato Quando/Dove/Partecipanti/CTA e segnala "Auto esposte rimandato
> a 04-GARAGE.md" — è la parte che dipende dal repository auto.

---

## 8. Step 5 — `CreateRadunoScreen`

Sostituisci lo stub con un form scrollabile. **Spec:** `raduni_app/HANDOFF.md`
§ 5.6.

Sezioni (in `Form` unico, scrollabile):

1. **Titolo** — `TextFormField`, validatore `not empty`.
2. **Sottotitolo** — opzionale.
3. **Data** — `showDatePicker` italiano, button mostra "10 mag 2026".
4. **Ora** — `showTimePicker`, button mostra "09:30".
5. **Pin sulla mappa** — `flutter_map` 200h, marker draggabile, callback
   `onTap` per spostare. Geocoding inverso (`geocoding` package) per popolare
   automaticamente "luogo" e "citta".
6. **Descrizione** — `TextFormField(maxLines: 6)`.
7. **Tag** — multi-select chips. Lista hardcoded: Storiche, Sportive, Track
   day, Italiane, Tedesche, Americane, Giapponesi, Lago, Montagna, Caffè,
   Sera.
8. **Max partecipanti** — `Slider` 10-500 con label.
9. **Gratuito** — `Switch`. Se off, mostra `TextFormField` numerico per
   prezzo.
10. **Cover** — `image_picker`. Mostra preview o pulsante "Aggiungi foto".

Bottone "Pubblica raduno" in fondo. Validazione →
`repository.create(...)` → `context.go('/raduno/$newId')` con `replace`
invece di `push`.

```dart
Future<void> _pubblica() async {
  if (!_formKey.currentState!.validate()) return;
  if (_pinPosition == null) {
    _showError('Seleziona una posizione sulla mappa');
    return;
  }
  setState(() => _publishing = true);
  try {
    final newId = await ref.read(raduniRepositoryProvider).create(
          titolo: _titoloCtrl.text.trim(),
          sottotitolo: _sottoCtrl.text.trim().isEmpty
              ? null
              : _sottoCtrl.text.trim(),
          quando: DateTime(_data.year, _data.month, _data.day, _ora.hour, _ora.minute),
          luogo: _luogo,
          citta: _citta,
          lat: _pinPosition!.latitude,
          lng: _pinPosition!.longitude,
          maxPartecipanti: _maxPart.toInt(),
          tag: _tagSelezionati,
          gratuito: _gratuito,
          prezzo: _gratuito ? null : double.tryParse(_prezzoCtrl.text),
          descrizione: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          coverFile: _coverFile,
        );
    if (mounted) {
      context.go('/raduno/$newId');
    }
  } on AppException catch (e) {
    _showError(e.message);
  } finally {
    if (mounted) setState(() => _publishing = false);
  }
}
```

> ⚠️ **Nota Importante:** quando si chiude la schermata "Crea" **dopo** aver
> creato un raduno, l'utente atterra sul nuovo raduno. Il back button da lì
> deve tornare a Home, **non** alla schermata Crea già chiusa. Per questo
> serve `context.go(...)` non `context.push(...)`.

> ⚠️ **Permessi iOS necessari per image_picker.** Aggiungi in
> `raduni_app/ios/Runner/Info.plist` (se non già presenti):
> ```xml
> <key>NSPhotoLibraryUsageDescription</key>
> <string>Raduni usa l'accesso alle foto per scegliere la cover dei tuoi raduni.</string>
> <key>NSCameraUsageDescription</key>
> <string>Raduni usa la fotocamera per scattare foto delle tue auto e dei raduni.</string>
> ```

---

## 9. Step 6 — Iscrizione / Disiscrizione

Bottom CTA della `DetailRadunoScreen`:

```dart
Consumer(
  builder: (context, ref, _) {
    final iscrittoAsync = ref.watch(isIscrittoProvider(id));
    return iscrittoAsync.when(
      loading: () => const FilledButton(
        onPressed: null,
        child: SizedBox(
          height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
      error: (_, __) => const SizedBox(),
      data: (iscritto) {
        if (iscritto) {
          return OutlinedButton.icon(
            onPressed: () => _disiscrivi(ref),
            icon: const Icon(Icons.check, color: AppColors.accent),
            label: const Text('Iscritto · Modifica auto esposta'),
          );
        }
        return FilledButton(
          onPressed: () => _iscrivi(ref),
          child: Text(raduno.gratuito
              ? 'Iscriviti gratis'
              : 'Iscriviti · €${raduno.prezzo!.toStringAsFixed(0)}'),
        );
      },
    );
  },
),
```

Dopo `iscriviti()` o `disiscriviti()`, fai:

```dart
ref.invalidate(isIscrittoProvider(id));
ref.invalidate(radunoDetailProvider(id));
```

per ricaricare il count partecipanti.

---

## 10. Empty / Error states

`raduni_app/lib/features/home/presentation/widgets/empty_state.dart`:

```dart
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 64, color: AppColors.inkSubtle),
          const SizedBox(height: 16),
          const Text(
            'Nessun raduno nelle vicinanze',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Prova ad allargare la zona o crea il primo!',
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
```

Stesso pattern per `_ErrorState`, con bottone "Riprova" che invalida il
provider.

---

## 11. Test manuali

1. **Home con sessione vuota su Supabase:** empty state visibile, no crash.
2. **Inserisci 1 raduno da SQL editor di Supabase:** pull to refresh sulla
   home → vedi la card.
3. **Tap su card:** apre dettaglio con cover, info, partecipanti = 0.
4. **Tap "Iscriviti gratis":** bottone mostra loader, poi diventa
   "Iscritto · ...". Pull to refresh dettaglio → partecipanti = 1.
5. **Crea raduno:** form validato, errori mostrati. Submit → carica cover
   su Storage → nuovo raduno appare in home.
6. **Filtri chip:** tap "Storiche" filtra correttamente.
7. **Scenario errore di rete:** spegni wifi → pull-to-refresh → error state
   con retry.

---

## 12. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Funzione `raduni_nearby` non creata su Supabase → tutta la home fallisce | **Alto** | All'errore di RPC, mostra messaggio chiaro: "Funzione DB non configurata, esegui SQL in 01-ARCHITETTURA.md" |
| Stream periodic = polling = consumo batteria + costi Supabase | **Medio** | Default 30s. Documentare di passare a Realtime nella fase 6 |
| Image picker su iOS senza Info.plist → crash silenzioso | **Medio** | Vedi nota in §8 sui permessi iOS. Su Android sono già configurati. |
| Geocoding inverso lento o offline → coordinate ok ma luogo/citta vuoti | **Basso** | Permetti compilazione manuale dei due campi anche se geocoding fallisce |
| Cover upload fallisce a metà → riga `raduni` con `cover_url` non valido | **Medio** | Fai upload **prima** dell'insert. Se upload fallisce → no insert. È già il pattern in §4 |

---

## 13. Definition of Done

- [ ] `geocoding: ^3.0.0` aggiunto al `pubspec.yaml`
- [ ] `lib/features/home/data/raduni_repository.dart` con tutti i metodi
- [ ] `lib/features/home/application/raduni_providers.dart`
- [ ] `lib/features/raduno/application/raduno_detail_providers.dart`
- [ ] `home_screen.dart` non usa più `MockData`
- [ ] Pull-to-refresh funziona
- [ ] Filter chips funzionano
- [ ] Loading / error / empty states implementati
- [ ] `DetailRadunoScreen` completa con tutte le sezioni di § 7
- [ ] `CreateRadunoScreen` con form completo + upload cover
- [ ] Iscrizione / disiscrizione funzionanti
- [ ] Pin sulla mappa nel form Crea trascinabile
- [ ] Permessi iOS aggiornati per image_picker
- [ ] Tutti i 7 test manuali §11 passano
- [ ] `cd raduni_app && flutter analyze` pulito
- [ ] `raduni_app/HANDOFF.md` aggiornato (sezioni 5.3, 5.5, 5.6 da TODO a "✅ FATTA")

Quando completo:

> "Raduni completato. Home, Dettaglio e Crea sono operativi con Supabase. Pronto per Mappa (`claude/03-MAPPA.md`) o Garage (`claude/04-GARAGE.md`)."
