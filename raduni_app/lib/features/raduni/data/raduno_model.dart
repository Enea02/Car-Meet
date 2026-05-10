class Raduno {
  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final String locationName;
  final String? address;
  final double lat;
  final double lng;
  final int entryPriceCents;
  final int? maxAttendees;
  final String? coverImageUrl;
  final String status;
  final DateTime createdAt;
  final double? distanceKm;

  const Raduno({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    required this.startAt,
    this.endAt,
    required this.locationName,
    this.address,
    required this.lat,
    required this.lng,
    required this.entryPriceCents,
    this.maxAttendees,
    this.coverImageUrl,
    required this.status,
    required this.createdAt,
    this.distanceKm,
  });

  bool get isFree => entryPriceCents == 0;
  double get entryPriceEuro => entryPriceCents / 100;

  factory Raduno.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    double lat = 0, lng = 0;
    if (loc is Map && loc['coordinates'] is List) {
      final coords = loc['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else if (json['lat'] != null && json['lng'] != null) {
      lat = (json['lat'] as num).toDouble();
      lng = (json['lng'] as num).toDouble();
    }

    return Raduno(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      locationName: json['location_name'] as String? ?? '',
      address: json['address'] as String?,
      lat: lat,
      lng: lng,
      entryPriceCents: (json['entry_price_cents'] as num?)?.toInt() ?? 0,
      maxAttendees: (json['max_attendees'] as num?)?.toInt(),
      coverImageUrl: json['cover_image_url'] as String?,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
