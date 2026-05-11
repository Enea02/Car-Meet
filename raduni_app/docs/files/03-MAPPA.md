# 03 — MAPPA

> **Subagente:** Mappa interattiva
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** `00-BOOTSTRAP.md` + `01-AUTH.md` + `02-RADUNI.md` (serve `RaduniRepository`).
> **Output:** `MapScreen` funzionante con marker raduni clusterizzati, geolocator, bottom sheet preview.
> **Stima:** 6-8 ore di lavoro Claude Code

---

## 1. Obiettivo

Trasformare `lib/features/map/presentation/map_screen.dart` da stub a mappa
interattiva completa. Nessuna modifica ai dati: legge dallo stesso
`RaduniRepository` creato in `02-RADUNI.md`.

**Tre pezzi:**

1. Mappa `flutter_map` con tile OpenStreetMap.
2. Marker custom per raduni + cluster a zoom basso.
3. Bottom sheet con preview del raduno tappato + tap → dettaglio.

> ✋ **Vincolo:** la `MapScreen` apre quando l'utente tocca il tab "Mappa"
> della `AppShell`. Non deve avere il proprio `Scaffold` con `AppBar`. La
> `HomeScreen` esistente usa solo `SafeArea + CustomScrollView` — segui lo
> stesso pattern.

### Dipendenze da aggiungere al `pubspec.yaml`

```yaml
  flutter_map_marker_cluster: ^1.3.6
```

Dopo l'aggiunta:

```bash
cd raduni_app && flutter pub get
```

> ⚠️ `flutter_map: ^7.0.0`, `latlong2: ^0.9.0`, `geolocator: ^12.0.0`,
> `permission_handler: ^11.0.0` sono **già installati** nel `pubspec.yaml`
> di `raduni_app/`. Non re-aggiungerli.

---

## 2. Stack mappa — vincoli

| Componente | Scelta | Motivo |
|---|---|---|
| Engine | `flutter_map: ^7.0.0` | Già in `pubspec.yaml`, gratis, no API key |
| Tile provider | OpenStreetMap Mapnik | Default flutter_map, attribution obbligatorio |
| Cluster | `flutter_map_marker_cluster: ^1.3.6` | Da aggiungere |
| Geo posizione | `geolocator: ^12.0.0` | Già in `pubspec.yaml` |
| Permessi | `permission_handler: ^11.0.0` | Già in `pubspec.yaml` |

**Mai usare** `google_maps_flutter`. Richiederebbe API key con costi
ricorrenti.

> ⚠️ **Nota Importante:** il tile server di OpenStreetMap ha policy di uso
> "ragionevole". In produzione con >5k utenti attivi/mese passa a un provider
> come MapTiler (free tier 100k tiles/mese) o Stadia. Per MVP OSM va bene.
> Documentare in `02-FASI-IMPLEMENTAZIONE.md` come task della Fase 6.

---

## 3. Permessi piattaforma

### iOS

`raduni_app/ios/Runner/Info.plist` — aggiungi se non già presente:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Raduni usa la tua posizione per mostrarti i raduni vicini.</string>
```

### Android

`raduni_app/android/app/src/main/AndroidManifest.xml` — **già configurato**.
Verifica che siano presenti (lo sono al momento di scrittura di questo doc):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Se mancano, aggiungili dentro `<manifest>` prima di `<application>`.

---

## 4. Architettura della feature

```
features/map/
├── application/
│   └── map_providers.dart          # Da creare (opzionale per MVP)
└── presentation/
    ├── map_screen.dart             # Da costruire da zero
    └── widgets/                    # Da creare
        ├── raduno_marker.dart
        ├── cluster_marker.dart
        └── raduno_preview_sheet.dart
```

```bash
mkdir -p raduni_app/lib/features/map/presentation/widgets
mkdir -p raduni_app/lib/core/location
```

Il repository **non cambia** — riusa `raduniRepositoryProvider` da
`02-RADUNI.md`.

---

## 5. Step 1 — Provider geolocator

`raduni_app/lib/core/location/location_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Restituisce la posizione corrente o null se permessi negati.
  /// NON lancia eccezioni — la UI gestisce il null mostrando un fallback.
  Future<Position?> getCurrentPosition() async {
    try {
      // 1. Servizio attivo?
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      // 2. Permessi
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      // 3. Posizione
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Posizione corrente cachata. Refresh quando l'utente preme "centra".
final currentPositionProvider = FutureProvider<Position?>((ref) {
  return ref.watch(locationServiceProvider).getCurrentPosition();
});
```

> ✅ **Beneficio:** restituire `null` invece di lanciare eccezioni rende la UI
> molto più semplice: `if (position == null) → mostra Milano + banner "Attiva
> GPS"`.

---

## 6. Step 2 — `MapScreen` scheletro

`raduni_app/lib/features/map/presentation/map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/location/location_service.dart';
import '../../../shared/models/raduno.dart';
import '../../../theme/app_colors.dart';
import '../../home/application/raduni_providers.dart';
import 'widgets/raduno_marker.dart';
import 'widgets/raduno_preview_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  static const _milano = LatLng(45.4642, 9.1900);

  @override
  void initState() {
    super.initState();
    // Centra sulla posizione utente al primo build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pos = await ref.read(currentPositionProvider.future);
      if (pos != null && mounted) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 12);
        ref.read(userPositionProvider.notifier).state =
            (lat: pos.latitude, lng: pos.longitude);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final raduniAsync = ref.watch(raduniNearbyProvider);

    return Stack(
      children: [
        // ── Mappa
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _milano,
            initialZoom: 12,
            minZoom: 4,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.eneafrontera.raduniApp',
              subdomains: const ['a', 'b', 'c'],
            ),
            raduniAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (raduni) => _buildClusterLayer(raduni),
            ),
            // Attribuzione OSM (obbligatoria dalla policy OSM)
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // ── Search bar floating in alto
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: const _SearchBar(),
        ),

        // ── Bottone "centra su di me" in basso a destra
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'centra',
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
            elevation: 2,
            onPressed: _centraSuUtente,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildClusterLayer(List<Raduno> raduni) {
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: const Size(48, 48),
        markers: raduni.map(_buildMarker).toList(),
        builder: (ctx, markers) => ClusterMarker(count: markers.length),
        onClusterTap: (c) {},
      ),
    );
  }

  Marker _buildMarker(Raduno r) {
    return Marker(
      point: LatLng(r.lat, r.lng),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showPreview(r),
        child: RadunoMarker(partecipanti: r.partecipanti),
      ),
    );
  }

  void _showPreview(Raduno r) {
    _mapController.move(LatLng(r.lat, r.lng), _mapController.camera.zoom);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RadunoPreviewSheet(
        raduno: r,
        onTap: () {
          Navigator.pop(context);
          context.push('/raduno/${r.id}');
        },
      ),
    );
  }

  Future<void> _centraSuUtente() async {
    final pos = await ref.refresh(currentPositionProvider.future);
    if (pos == null) {
      _showSnack('Attiva la geolocalizzazione nelle impostazioni');
      return;
    }
    _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    ref.read(userPositionProvider.notifier).state =
        (lat: pos.latitude, lng: pos.longitude);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
```

> ⚠️ **Nota:** il `userAgentPackageName` deve corrispondere al **bundle id
> reale** del progetto: `com.eneafrontera.raduniApp` (vedi
> `ios/Runner/Configs/AppInfo.xcconfig` o `android/app/build.gradle`).
> Cambialo se in futuro modifichi il bundle id.

---

## 7. Step 3 — Marker custom

`raduni_app/lib/features/map/presentation/widgets/raduno_marker.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

class RadunoMarker extends StatelessWidget {
  final int partecipanti;
  const RadunoMarker({super.key, required this.partecipanti});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          partecipanti.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class ClusterMarker extends StatelessWidget {
  final int count;
  const ClusterMarker({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
```

> ⚠️ **Nota:** uso `withValues(alpha: ...)` (Flutter 3.27+) invece di
> `withOpacity(...)` deprecato. Se in `app_colors.dart` o altrove vedi ancora
> `withOpacity`, **non sostituirli** in massa: solo nei file nuovi che crei.

---

## 8. Step 4 — Bottom sheet preview

`raduni_app/lib/features/map/presentation/widgets/raduno_preview_sheet.dart`:

Riusa il layout di `CompactRadunoCard` (è già in `lib/shared/widgets/`)
adattato a bottom sheet (drag handle in cima, padding più generoso).
**Non duplicare** il layout della card — passa per `CompactRadunoCard`.

```dart
import 'package:flutter/material.dart';
import '../../../../shared/models/raduno.dart';
import '../../../../shared/widgets/compact_raduno_card.dart';
import '../../../../theme/app_colors.dart';

class RadunoPreviewSheet extends StatelessWidget {
  final Raduno raduno;
  final VoidCallback onTap;
  const RadunoPreviewSheet({super.key, required this.raduno, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CompactRadunoCard(raduno: raduno, onTap: onTap),
          ],
        ),
      ),
    );
  }
}
```

> ⚠️ **Verifica firma di `CompactRadunoCard`:** prima di scrivere il codice
> sopra, **leggi** il file `lib/shared/widgets/compact_raduno_card.dart` per
> confermare che il costruttore accetta `raduno` e `onTap` con questi nomi
> esatti. Se ha nomi diversi, adatta.

---

## 9. Step 5 — Search bar floating

Versione semplificata della home — è un placeholder visivo per ora. La ricerca
testuale vera è fuori scope (sarebbe full-text search Postgres).

```dart
class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.inkSubtle, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cerca su mappa…',
              style: TextStyle(fontSize: 14, color: AppColors.inkSubtle),
            ),
          ),
          const Icon(Icons.tune, color: AppColors.inkMuted, size: 20),
        ],
      ),
    );
  }
}
```

> ✋ La logica di filtri "Oggi", "Weekend", "Storiche" descritta in
> `HANDOFF.md` § 5.4 può andare in un `BottomSheet` aperto dal tap sull'icona
> `tune`. **Implementala solo se il tempo lo permette** — non bloccare la
> consegna del task.

---

## 10. Test manuali

1. **Apertura mappa, primo lancio:**
   - Permessi GPS richiesti → tap "Allow".
   - Mappa centra su posizione reale dell'utente.
   - Vedi i raduni di Supabase come marker.
2. **Permessi negati:**
   - Stessa rotta, ma negando i permessi.
   - Mappa parte centrata su Milano. No crash.
   - Bottone "centra" → snackbar "Attiva la geolocalizzazione...".
3. **Cluster:**
   - Zoom out fino a vedere tutta Italia.
   - I marker raggruppati mostrano il numero totale, non più i singoli pin.
4. **Tap marker:**
   - Bottom sheet appare con `CompactRadunoCard`.
   - Tap sulla card → dettaglio.
5. **Pull mappa:**
   - Pan e zoom fluidi (60fps).
   - Tile caching: zoom in poi out → no re-download visibile.
6. **Modalità aereo:**
   - Tile non caricano → solo sfondo grigio. Marker comunque mostrati. No crash.
7. **Cambio tab e ritorno:**
   - Vai su Home, torna su Mappa.
   - Stato camera **non** preservato (ricomincia da Milano/utente). Documentato e accettabile per MVP.

---

## 11. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Tile OSM rate-limited con molti utenti | **Medio** | Documenta passaggio a MapTiler in fase 6. Per ora OSM ok. |
| Cluster con 500+ marker → frame drop | **Medio** | `maxClusterRadius: 60` aggressivo, `disableClusteringAtZoom: 16` |
| `Geolocator.getCurrentPosition` in iOS Simulator → coordinate Apple HQ (Cupertino) | **Basso** | Documentato. In simulatore: Debug → Location → Custom Location |
| `flutter_map` v7 ha breaking changes vs v6 (parametri rinominati) | **Medio** | Riferimento doc: pub.dev/packages/flutter_map. Non copiare snippet vecchi da Stack Overflow |
| Marker sovrapposti se 2 raduni hanno stesse coordinate | **Basso** | Cluster ne raggruppa automaticamente |

---

## 12. Definition of Done

- [ ] `flutter_map_marker_cluster: ^1.3.6` aggiunto al `pubspec.yaml`
- [ ] `lib/core/location/location_service.dart` con `LocationService` e provider
- [ ] `lib/features/map/presentation/map_screen.dart` con `FlutterMap`
- [ ] Marker custom + cluster funzionanti
- [ ] Bottom sheet preview che apre dettaglio
- [ ] Bottone "centra su di me" funzionante
- [ ] Permessi iOS Info.plist aggiornati per location (se mancanti)
- [ ] Attribuzione OSM visibile (RichAttributionWidget)
- [ ] App parte centrata su utente o Milano (fallback)
- [ ] Tutti i 7 test manuali §10 passati
- [ ] `cd raduni_app && flutter analyze` pulito
- [ ] `raduni_app/HANDOFF.md` aggiornato (sezione 5.4 da TODO a "✅ FATTA")

Quando completo:

> "Mappa completata. Marker, cluster, geolocator e preview sheet operativi. Pronto per Garage (`claude/04-GARAGE.md`)."
