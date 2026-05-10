class DistanceFormatter {
  static String format(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.round()} km';
  }
}
