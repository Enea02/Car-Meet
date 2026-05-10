import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/auto_model.dart';
import '../data/auto_repository.dart';

final autoRepositoryProvider = Provider<AutoRepository>((ref) {
  return AutoRepository(ref.watch(supabaseClientProvider));
});

final myGarageProvider = FutureProvider<List<Auto>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(autoRepositoryProvider).fetchByOwner(userId);
});

final autoByIdProvider =
    FutureProvider.family<Auto, String>((ref, id) {
  return ref.watch(autoRepositoryProvider).fetchById(id);
});

final exhibitionsForRadunoProvider =
    FutureProvider.family<List<AutoExhibition>, String>((ref, radunoId) {
  return ref
      .watch(autoRepositoryProvider)
      .fetchExhibitionsForRaduno(radunoId);
});
