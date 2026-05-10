import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  Future<Profile?> fetchById(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<Profile> update({
    required String userId,
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    final row = await _client
        .from('profiles')
        .update({
          'username': username,
          'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(row);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}
