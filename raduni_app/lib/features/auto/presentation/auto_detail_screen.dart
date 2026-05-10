import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../providers/auto_providers.dart';

class AutoDetailScreen extends ConsumerWidget {
  final String autoId;
  const AutoDetailScreen({super.key, required this.autoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAsync = ref.watch(autoByIdProvider(autoId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home/garage'),
        ),
        title: const Text('Dettaglio auto'),
      ),
      body: autoAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(error: e),
        data: (auto) => ListView(
          children: [
            if (auto.photoUrls.isNotEmpty)
              SizedBox(
                height: 240,
                child: PageView(
                  children: [
                    for (final url in auto.photoUrls)
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.black12),
                      ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.directions_car, size: 80),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auto.displayName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  if (auto.description != null) ...[
                    const SizedBox(height: 12),
                    Text(auto.description!),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminare l\'auto?'),
                          content: const Text(
                              'Verranno cancellate anche le foto.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Annulla')),
                            FilledButton.tonal(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Elimina')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await ref
                          .read(autoRepositoryProvider)
                          .delete(auto.id);
                      ref.invalidate(myGarageProvider);
                      if (context.mounted) context.go('/home/garage');
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Elimina auto'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
