import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/raduno_card.dart';
import '../../map/providers/location_providers.dart';
import '../providers/raduni_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(currentPositionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raduni vicini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(currentPositionProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/raduni/create'),
        icon: const Icon(Icons.add),
        label: const Text('Crea raduno'),
      ),
      body: position.when(
        loading: () => const LoadingIndicator(label: 'Cerco la tua posizione…'),
        error: (e, _) => _NoPositionFallback(error: e),
        data: (pos) {
          final raduni = ref.watch(raduniNearbyProvider(NearbyParams(
            lat: pos.latitude,
            lng: pos.longitude,
          )));
          return raduni.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(raduniNearbyProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyView(
                  icon: Icons.event_busy,
                  title: 'Nessun raduno entro 50 km',
                  subtitle: 'Sii il primo a crearne uno!',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(raduniNearbyProvider);
                  await ref.read(raduniNearbyProvider(NearbyParams(
                    lat: pos.latitude,
                    lng: pos.longitude,
                  )).future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) => RadunoCard(
                    raduno: list[i],
                    onTap: () => context.go('/home/raduni/${list[i].id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoPositionFallback extends ConsumerWidget {
  final Object error;
  const _NoPositionFallback({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raduni = ref.watch(raduniListStreamProvider);
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.location_off_outlined),
            title: const Text('Posizione non disponibile'),
            subtitle: Text(error.toString()),
            trailing: TextButton(
              onPressed: () => ref.invalidate(currentPositionProvider),
              child: const Text('Riprova'),
            ),
          ),
        ),
        Expanded(
          child: raduni.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(error: e),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyView(
                  icon: Icons.event_busy,
                  title: 'Nessun raduno disponibile',
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => RadunoCard(
                  raduno: list[i],
                  onTap: () =>
                      GoRouter.of(context).go('/home/raduni/${list[i].id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
