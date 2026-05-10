import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auto/data/auto_model.dart';
import '../../auto/providers/auto_providers.dart';
import '../data/raduno_model.dart';
import '../providers/raduni_providers.dart';

class RadunoDetailScreen extends ConsumerWidget {
  final String radunoId;
  const RadunoDetailScreen({super.key, required this.radunoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radunoAsync = ref.watch(radunoByIdProvider(radunoId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home/raduni'),
        ),
        title: const Text('Dettaglio raduno'),
      ),
      body: radunoAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(radunoByIdProvider(radunoId)),
        ),
        data: (raduno) => _RadunoDetailBody(raduno: raduno),
      ),
    );
  }
}

class _RadunoDetailBody extends ConsumerWidget {
  final Raduno raduno;
  const _RadunoDetailBody({required this.raduno});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('EEE d MMMM y • HH:mm', 'it_IT');
    final userId = ref.watch(currentUserIdProvider);
    final isOrganizer = userId == raduno.organizerId;
    final isAttending = ref.watch(isAttendingProvider(raduno.id));
    final attendees = ref.watch(attendanceCountProvider(raduno.id));
    final exhibitions = ref.watch(exhibitionsForRadunoProvider(raduno.id));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (raduno.coverImageUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: raduno.coverImageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.black12),
              errorWidget: (_, __, ___) => Container(color: Colors.black12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(raduno.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _Row(icon: Icons.calendar_today,
                  text: dateFmt.format(raduno.startAt.toLocal())),
              _Row(icon: Icons.place_outlined, text: raduno.locationName),
              if (raduno.address != null)
                _Row(icon: Icons.map_outlined, text: raduno.address!),
              _Row(
                icon: raduno.isFree ? Icons.celebration : Icons.euro,
                text: raduno.isFree
                    ? 'Ingresso gratuito'
                    : '${raduno.entryPriceEuro.toStringAsFixed(2)} €',
              ),
              attendees.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (n) => _Row(
                  icon: Icons.people_outline,
                  text: '$n iscritt${n == 1 ? 'o' : 'i'}',
                ),
              ),
              if (raduno.description != null && raduno.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Descrizione',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(raduno.description!),
              ],
              const SizedBox(height: 24),
              if (!isOrganizer) ...[
                isAttending.when(
                  loading: () => const FilledButton(
                      onPressed: null, child: Text('…')),
                  error: (e, _) => Text('Errore: $e'),
                  data: (attending) => Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final repo = ref.read(raduniRepositoryProvider);
                            if (userId == null) return;
                            if (attending) {
                              await repo.unattend(
                                  radunoId: raduno.id, userId: userId);
                            } else {
                              await repo.attend(
                                  radunoId: raduno.id, userId: userId);
                            }
                            ref.invalidate(isAttendingProvider(raduno.id));
                            ref.invalidate(attendanceCountProvider(raduno.id));
                          },
                          icon: Icon(attending
                              ? Icons.check_circle
                              : Icons.add_circle_outline),
                          label: Text(attending
                              ? 'Sei iscritto'
                              : 'Iscriviti come visitatore'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showExhibitDialog(context, ref, raduno.id),
                  icon: const Icon(Icons.directions_car_outlined),
                  label: const Text('Esponi una mia auto'),
                ),
              ] else ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmDelete(context, ref, raduno.id),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Elimina raduno'),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
              Text('Auto esposte',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              exhibitions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('Errore: $e'),
                data: (list) {
                  if (list.isEmpty) {
                    return Text('Nessuna auto ancora esposta.',
                        style: Theme.of(context).textTheme.bodyMedium);
                  }
                  return Column(
                    children: list.map((ex) => _ExhibitionTile(ex: ex)).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare il raduno?'),
        content: const Text('L\'azione non è reversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(raduniRepositoryProvider).delete(id);
      if (context.mounted) context.go('/home/raduni');
    }
  }

  Future<void> _showExhibitDialog(
      BuildContext context, WidgetRef ref, String radunoId) async {
    final myAutoAsync = ref.read(myGarageProvider.future);
    final list = await myAutoAsync;
    if (!context.mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi prima un\'auto al tuo garage')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Quale auto vuoi esporre?')),
            ...list.map((auto) => ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text(auto.displayName),
                  onTap: () => Navigator.pop(context, auto.id),
                )),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref
          .read(autoRepositoryProvider)
          .registerExhibition(radunoId: radunoId, autoId: picked);
      ref.invalidate(exhibitionsForRadunoProvider(radunoId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto registrata al raduno')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ExhibitionTile extends StatelessWidget {
  final AutoExhibition ex;
  const _ExhibitionTile({required this.ex});

  @override
  Widget build(BuildContext context) {
    final auto = ex.auto;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: auto != null && auto.photoUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: auto.photoUrls.first,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.directions_car_filled),
        title: Text(auto?.displayName ?? 'Auto'),
        subtitle: ex.ownerDisplayName != null
            ? Text('di ${ex.ownerDisplayName}')
            : null,
      ),
    );
  }
}
