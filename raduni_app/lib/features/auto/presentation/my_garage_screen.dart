import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../providers/auto_providers.dart';

class MyGarageScreen extends ConsumerWidget {
  const MyGarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(myGarageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Il mio garage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/garage/add'),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi auto'),
      ),
      body: garage.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myGarageProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.garage_outlined,
              title: 'Nessuna auto nel garage',
              subtitle: 'Aggiungine una per esporla ai raduni.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myGarageProvider);
              await ref.read(myGarageProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final auto = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: auto.photoUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: auto.photoUrls.first,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.directions_car_filled, size: 36),
                    title: Text(auto.displayName),
                    subtitle: auto.description != null
                        ? Text(auto.description!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/home/garage/${auto.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
