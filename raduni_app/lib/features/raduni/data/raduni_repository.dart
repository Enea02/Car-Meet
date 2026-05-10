import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/wkt_helper.dart';
import 'raduno_model.dart';

class RaduniRepository {
  final SupabaseClient _client;
  RaduniRepository(this._client);

  Future<List<Raduno>> fetchNearby({
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async {
    final rows = await _client.rpc('raduni_nearby', params: {
      'user_lat': lat,
      'user_lng': lng,
      'radius_km': radiusKm,
    });
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.map(Raduno.fromJson).toList();
  }

  Future<List<Raduno>> fetchPublishedFuture({int limit = 100}) async {
    final rows = await _client
        .from('raduni')
        .select()
        .eq('status', 'published')
        .gt('start_at', DateTime.now().toIso8601String())
        .order('start_at')
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Raduno.fromJson)
        .toList();
  }

  Future<Raduno> fetchById(String id) async {
    final row = await _client.from('raduni').select().eq('id', id).single();
    return Raduno.fromJson(row);
  }

  Future<List<Raduno>> fetchOrganizedBy(String userId) async {
    final rows = await _client
        .from('raduni')
        .select()
        .eq('organizer_id', userId)
        .order('start_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Raduno.fromJson)
        .toList();
  }

  Future<Raduno> create({
    required String organizerId,
    required String title,
    String? description,
    required DateTime startAt,
    DateTime? endAt,
    required String locationName,
    String? address,
    required double lat,
    required double lng,
    required int entryPriceCents,
    int? maxAttendees,
    String? coverImageUrl,
  }) async {
    final row = await _client
        .from('raduni')
        .insert({
          'organizer_id': organizerId,
          'title': title,
          if (description != null) 'description': description,
          'start_at': startAt.toIso8601String(),
          if (endAt != null) 'end_at': endAt.toIso8601String(),
          'location_name': locationName,
          if (address != null) 'address': address,
          'location': WktHelper.point(lat: lat, lng: lng),
          'entry_price_cents': entryPriceCents,
          if (maxAttendees != null) 'max_attendees': maxAttendees,
          if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
          'status': 'published',
        })
        .select()
        .single();
    return Raduno.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('raduni').delete().eq('id', id);
  }

  Future<String> uploadCover({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('raduni-covers').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('raduni-covers').getPublicUrl(path);
  }

  Stream<List<Raduno>> watchPublished() {
    return _client
        .from('raduni')
        .stream(primaryKey: ['id'])
        .eq('status', 'published')
        .order('start_at')
        .map((rows) => rows.map(Raduno.fromJson).toList());
  }

  // Attendance
  Future<bool> isAttending({
    required String radunoId,
    required String userId,
  }) async {
    final row = await _client
        .from('attendances')
        .select('id')
        .eq('raduno_id', radunoId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> attend({
    required String radunoId,
    required String userId,
  }) async {
    await _client.from('attendances').insert({
      'raduno_id': radunoId,
      'user_id': userId,
    });
  }

  Future<void> unattend({
    required String radunoId,
    required String userId,
  }) async {
    await _client
        .from('attendances')
        .delete()
        .eq('raduno_id', radunoId)
        .eq('user_id', userId);
  }

  Future<int> attendanceCount(String radunoId) async {
    final rows = await _client
        .from('attendances')
        .select('id')
        .eq('raduno_id', radunoId);
    return (rows as List).length;
  }
}
