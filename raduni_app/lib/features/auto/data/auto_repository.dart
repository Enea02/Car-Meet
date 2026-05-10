import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auto_model.dart';

class AutoRepository {
  final SupabaseClient _client;
  AutoRepository(this._client);

  Future<List<Auto>> fetchByOwner(String ownerId) async {
    final rows = await _client
        .from('auto')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Auto.fromJson)
        .toList();
  }

  Future<Auto> fetchById(String id) async {
    final row = await _client.from('auto').select().eq('id', id).single();
    return Auto.fromJson(row);
  }

  Future<Auto> create({
    required String ownerId,
    required String make,
    required String model,
    int? year,
    String? description,
    List<String> photoUrls = const [],
  }) async {
    final row = await _client
        .from('auto')
        .insert({
          'owner_id': ownerId,
          'make': make,
          'model': model,
          if (year != null) 'year': year,
          if (description != null) 'description': description,
          'photo_urls': photoUrls,
        })
        .select()
        .single();
    return Auto.fromJson(row);
  }

  Future<void> delete(String id) async {
    final auto = await fetchById(id);
    final paths = auto.photoUrls
        .map(_extractStoragePath)
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from('auto-photos').remove(paths);
      } catch (_) {
        // best effort
      }
    }
    await _client.from('auto').delete().eq('id', id);
  }

  Future<String> uploadPhoto({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('auto-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('auto-photos').getPublicUrl(path);
  }

  String? _extractStoragePath(String publicUrl) {
    final marker = '/auto-photos/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return null;
    return publicUrl.substring(idx + marker.length);
  }

  // Exhibitions
  Future<List<AutoExhibition>> fetchExhibitionsForRaduno(String radunoId) async {
    final rows = await _client
        .from('auto_exhibitions')
        .select('*, auto:auto_id(*, owner:owner_id(display_name))')
        .eq('raduno_id', radunoId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AutoExhibition.fromJson)
        .toList();
  }

  Future<void> registerExhibition({
    required String radunoId,
    required String autoId,
  }) async {
    await _client.from('auto_exhibitions').insert({
      'raduno_id': radunoId,
      'auto_id': autoId,
      'status': 'approved',
    });
  }

  Future<void> removeExhibition({
    required String radunoId,
    required String autoId,
  }) async {
    await _client
        .from('auto_exhibitions')
        .delete()
        .eq('raduno_id', radunoId)
        .eq('auto_id', autoId);
  }
}
