class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String? ?? 'Utente',
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toUpdateJson() => {
        'username': username,
        'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

  Profile copyWith({String? username, String? displayName, String? avatarUrl}) {
    return Profile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}
