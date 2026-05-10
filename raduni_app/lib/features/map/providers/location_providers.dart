import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentPositionProvider = FutureProvider<Position>((ref) {
  return ref.watch(locationServiceProvider).getCurrentPosition();
});
