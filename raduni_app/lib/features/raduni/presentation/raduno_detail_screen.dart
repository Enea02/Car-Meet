import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.bg,
      body: radunoAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(radunoByIdProvider(radunoId)),
        ),
        data: (raduno) => _DetailBody(raduno: raduno),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Raduno raduno;
  const _DetailBody({required this.raduno});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLong = DateFormat('EEEE d MMMM y', 'it_IT');
    final timeOnly = DateFormat('HH:mm', 'it_IT');
    final userId = ref.watch(currentUserIdProvider);
    final isOrganizer = userId == raduno.organizerId;
    final isAttending = ref.watch(isAttendingProvider(raduno.id));
    final attendees = ref.watch(attendanceCountProvider(raduno.id));
    final exhibitions = ref.watch(exhibitionsForRadunoProvider(raduno.id));

    return CustomScrollView(
      slivers: [
        // ── Cover SliverAppBar
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/home/raduni'),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: raduno.coverImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: raduno.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.surfaceMuted),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.surfaceMuted),
                  )
                : Container(
                    color: AppColors.surfaceMuted,
                    child: const Icon(Icons.directions_car_outlined,
                        size: 64, color: AppColors.inkSubtle),
                  ),
          ),
        ),

        // ── Content
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Title
              Text(
                raduno.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),

              // Info rows
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLong.format(raduno.startAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Ore ${timeOnly.format(raduno.startAt.toLocal())}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _InfoRow(
                icon: Icons.place_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raduno.locationName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    if (raduno.address != null)
                      Text(
                        raduno.address!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.inkMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _InfoRow(
                icon: raduno.isFree ? Icons.celebration_outlined : Icons.euro,
                child: Text(
                  raduno.isFree
                      ? 'Ingresso gratuito'
                      : '${raduno.entryPriceEuro.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              attendees.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (n) => _InfoRow(
                  icon: Icons.people_outline,
                  child: Text(
                    '$n iscritt${n == 1 ? 'o' : 'i'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),

              // Description
              if (raduno.description != null &&
                  raduno.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Descrizione',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  raduno.description!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Auto esposte section
              const Text(
                'Auto esposte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              exhibitions.when(
                loading: () =>
                    const LinearProgressIndicator(color: AppColors.accent),
                error: (e, _) =>
                    Text('Errore: $e', style: const TextStyle(fontSize: 13)),
                data: (list) {
                  if (list.isEmpty) {
                    return const Text(
                      'Nessuna auto ancora esposta.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.inkMuted),
                    );
                  }
                  return Column(
                    children: list
                        .map((ex) => _ExhibitionTile(ex: ex))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: 32),

              // CTA
              if (!isOrganizer) ...[
                isAttending.when(
                  loading: () =>
                      const FilledButton(onPressed: null, child: Text('…')),
                  error: (e, _) =>
                      Text('Errore: $e', style: const TextStyle(fontSize: 13)),
                  data: (attending) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          if (userId == null) return;
                          final repo = ref.read(raduniRepositoryProvider);
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
                        label: Text(
                            attending ? 'Sei iscritto' : 'Iscriviti gratis'),
                        style: attending
                            ? FilledButton.styleFrom(
                                backgroundColor: AppColors.accentSoft,
                                foregroundColor: AppColors.accent,
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showExhibitDialog(context, ref, raduno.id),
                        icon: const Icon(Icons.directions_car_outlined),
                        label: const Text('Esponi una mia auto'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context, ref, raduno.id),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  label: const Text('Elimina raduno',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
            ]),
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
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminare il raduno?'),
        content:
            const Text('L\'azione non è reversibile.'),
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
    final list = await ref.read(myGarageProvider.future);
    if (!context.mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aggiungi prima un\'auto al tuo garage')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const ListTile(
              title: Text('Quale auto vuoi esporre?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...list.map((auto) => ListTile(
                  leading: const Icon(Icons.directions_car_outlined,
                      color: AppColors.inkMuted),
                  title: Text(auto.displayName),
                  onTap: () => Navigator.pop(context, auto.id),
                )),
            const SizedBox(height: 8),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _InfoRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

class _ExhibitionTile extends StatelessWidget {
  final AutoExhibition ex;
  const _ExhibitionTile({required this.ex});

  @override
  Widget build(BuildContext context) {
    final auto = ex.auto;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: auto != null && auto.photoUrls.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: auto.photoUrls.first,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 52,
                    height: 52,
                    color: AppColors.surfaceMuted,
                    child: const Icon(Icons.directions_car_outlined,
                        color: AppColors.inkSubtle, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auto?.displayName ?? 'Auto',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (ex.ownerDisplayName != null)
                  Text(
                    'di ${ex.ownerDisplayName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
