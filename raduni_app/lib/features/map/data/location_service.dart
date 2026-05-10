import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  final String message;
  final LocationErrorKind kind;
  const LocationException(this.kind, this.message);
  @override
  String toString() => message;
}

enum LocationErrorKind { serviceDisabled, denied, deniedForever, timeout }

class LocationService {
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationErrorKind.serviceDisabled,
        'Servizi di localizzazione disattivati. Attivali nelle Impostazioni.',
      );
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException(
        LocationErrorKind.denied,
        'Permesso di localizzazione negato.',
      );
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationErrorKind.deniedForever,
        'Permesso di localizzazione negato definitivamente. Apri le Impostazioni per abilitarlo.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: timeout,
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
