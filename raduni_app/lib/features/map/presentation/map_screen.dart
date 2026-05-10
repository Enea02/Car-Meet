import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/distance_formatter.dart';
import '../../raduni/data/raduno_model.dart';
import '../../raduni/providers/raduni_providers.dart';
import '../data/location_service.dart';
import '../providers/location_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Timer? _debounce;
  double _radiusKm = 50;
  static const _italyCenter = LatLng(42.5, 12.5);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapEvent(MapEvent ev) {
    if (ev is MapEventMoveEnd ||
        ev is MapEventFlingAnimationEnd ||
        ev is MapEventDoubleTapZoomEnd) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(currentPositionProvider);
    final center = position.maybeWhen(
      data: (p) => LatLng(p.latitude, p.longitude),
      orElse: () => _italyCenter,
    );
    final initialZoom = position.hasValue ? 11.0 : 6.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappa raduni'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text('Raggio:'),
                Expanded(
                  child: Slider(
                    value: _radiusKm,
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: '${_radiusKm.round()} km',
                    onChanged: (v) => setState(() => _radiusKm = v),
                  ),
                ),
                Text('${_radiusKm.round()} km'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: initialZoom,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.eneafrontera.raduni_app',
              ),
              if (position.hasValue)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(position.value!.latitude,
                        position.value!.longitude),
                    width: 24,
                    height: 24,
                    child: const _UserDot(),
                  ),
                ]),
              _RaduniMarkers(
                center: _currentMapCenter() ?? center,
                radiusKm: _radiusKm,
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  onPressed: () async {
                    ref.invalidate(currentPositionProvider);
                    try {
                      final pos = await ref.read(currentPositionProvider.future);
                      _mapController.move(
                          LatLng(pos.latitude, pos.longitude), 11);
                    } catch (_) {}
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'reload',
                  onPressed: () => setState(() {}),
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (position is AsyncError)
            _PermissionBanner(error: position.error!),
        ],
      ),
    );
  }

  LatLng? _currentMapCenter() {
    try {
      return _mapController.camera.center;
    } catch (_) {
      return null;
    }
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(blurRadius: 4, color: Colors.black26),
        ],
      ),
    );
  }
}

class _RaduniMarkers extends ConsumerWidget {
  final LatLng center;
  final double radiusKm;
  const _RaduniMarkers({required this.center, required this.radiusKm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raduni = ref.watch(raduniNearbyProvider(NearbyParams(
      lat: center.latitude,
      lng: center.longitude,
      radiusKm: radiusKm,
    )));
    return raduni.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => MarkerLayer(
        markers: [
          for (final r in list)
            Marker(
              point: LatLng(r.lat, r.lng),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _showSheet(context, r),
                child: Icon(Icons.location_pin,
                    size: 44, color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, Raduno r) {
    final dateFmt = DateFormat('EEE d MMM • HH:mm', 'it_IT');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(dateFmt.format(r.startAt.toLocal())),
              Text(r.locationName),
              if (r.distanceKm != null)
                Text(DistanceFormatter.format(r.distanceKm!)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home/raduni/${r.id}');
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Vedi dettagli'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionBanner extends ConsumerWidget {
  final Object error;
  const _PermissionBanner({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPermanent = error is LocationException &&
        (error as LocationException).kind ==
            LocationErrorKind.deniedForever;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: SafeArea(
          bottom: false,
          child: ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Posizione non disponibile'),
            subtitle: Text(error.toString()),
            trailing: TextButton(
              onPressed: () async {
                if (isPermanent) {
                  await ref.read(locationServiceProvider).openAppSettings();
                } else {
                  ref.invalidate(currentPositionProvider);
                }
              },
              child: Text(isPermanent ? 'Impostazioni' : 'Riprova'),
            ),
          ),
        ),
      ),
    );
  }
}
