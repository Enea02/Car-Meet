class Auto {
  final String id;
  final String ownerId;
  final String make;
  final String model;
  final int? year;
  final String? description;
  final List<String> photoUrls;
  final DateTime createdAt;

  const Auto({
    required this.id,
    required this.ownerId,
    required this.make,
    required this.model,
    this.year,
    this.description,
    this.photoUrls = const [],
    required this.createdAt,
  });

  String get displayName =>
      [make, model, if (year != null) '($year)'].join(' ');

  factory Auto.fromJson(Map<String, dynamic> json) => Auto(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        make: json['make'] as String,
        model: json['model'] as String,
        year: (json['year'] as num?)?.toInt(),
        description: json['description'] as String?,
        photoUrls: (json['photo_urls'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class AutoExhibition {
  final String id;
  final String radunoId;
  final String autoId;
  final String status;
  final DateTime createdAt;
  final Auto? auto;
  final String? ownerDisplayName;

  const AutoExhibition({
    required this.id,
    required this.radunoId,
    required this.autoId,
    required this.status,
    required this.createdAt,
    this.auto,
    this.ownerDisplayName,
  });

  factory AutoExhibition.fromJson(Map<String, dynamic> json) {
    final autoJson = json['auto'] as Map<String, dynamic>?;
    final ownerJson = autoJson?['owner'] as Map<String, dynamic>?;
    return AutoExhibition(
      id: json['id'] as String,
      radunoId: json['raduno_id'] as String,
      autoId: json['auto_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      auto: autoJson != null ? Auto.fromJson(autoJson) : null,
      ownerDisplayName: ownerJson?['display_name'] as String?,
    );
  }
}
