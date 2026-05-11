import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/raduni_repository.dart';
import '../data/raduno_model.dart';

final raduniRepositoryProvider = Provider<RaduniRepository>((ref) {
  return RaduniRepository(ref.watch(supabaseClientProvider));
});

class NearbyParams {
  final double lat;
  final double lng;
  final double radiusKm;
  const NearbyParams({
    required this.lat,
    required this.lng,
    this.radiusKm = 50,
  });

  @override
  bool operator ==(Object other) =>
      other is NearbyParams &&
      lat == other.lat &&
      lng == other.lng &&
      radiusKm == other.radiusKm;

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm);
}

final raduniNearbyProvider =
    FutureProvider.family<List<Raduno>, NearbyParams>((ref, p) {
  final repo = ref.watch(raduniRepositoryProvider);
  return repo.fetchNearby(lat: p.lat, lng: p.lng, radiusKm: p.radiusKm);
});

final raduniListStreamProvider = StreamProvider<List<Raduno>>((ref) {
  return ref.watch(raduniRepositoryProvider).watchPublished();
});

final radunoByIdProvider =
    FutureProvider.family<Raduno, String>((ref, id) async {
  return ref.watch(raduniRepositoryProvider).fetchById(id);
});

final isAttendingProvider =
    FutureProvider.family<bool, String>((ref, radunoId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  return ref
      .watch(raduniRepositoryProvider)
      .isAttending(radunoId: radunoId, userId: userId);
});

final attendanceCountProvider =
    FutureProvider.family<int, String>((ref, radunoId) {
  return ref.watch(raduniRepositoryProvider).attendanceCount(radunoId);
});

final myAttendedRaduniProvider = FutureProvider<List<Raduno>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(raduniRepositoryProvider).fetchAttendedByUser(userId);
});

final myOrganizedRaduniProvider = FutureProvider<List<Raduno>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(raduniRepositoryProvider).fetchOrganizedBy(userId);
});

// Count of raduni attended by the current user (for profile stats)
final myAttendedCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('attendances')
      .select('id')
      .eq('user_id', userId);
  return (rows as List).length;
});

// Filter state for home screen
enum HomeFilter { tutti, settimana, gratuiti, pagamento }

final homeFilterProvider = StateProvider<HomeFilter>((ref) => HomeFilter.tutti);
