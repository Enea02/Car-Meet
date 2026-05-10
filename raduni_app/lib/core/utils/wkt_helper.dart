class WktHelper {
  static String point({required double lat, required double lng}) {
    return 'POINT($lng $lat)';
  }
}
