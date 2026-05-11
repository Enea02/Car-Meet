import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/raduno_card.dart';
import '../../map/providers/location_providers.dart';
import '../../profile/data/profile_model.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/raduno_model.dart';
import '../providers/raduni_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  List<Raduno> _applyFilter(List<Raduno> list, HomeFilter filter) {
    switch (filter) {
      case HomeFilter.tutti:
        return list;
      case HomeFilter.settimana:
        final deadline = DateTime.now().add(const Duration(days: 7));
        return list
            .where((r) => r.startAt.isBefore(deadline))
            .toList();
      case HomeFilter.gratuiti:
        return list.where((r) => r.isFree).toList();
      case HomeFilter.pagamento:
        return list.where((r) => !r.isFree).toList();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(currentPositionProvider);
    final filter = ref.watch(homeFilterProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    final displayName = profileAsync.maybeWhen(
      data: (p) => p?.displayName.split(' ').first ?? 'amico',
      orElse: () => 'amico',
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Header (greeting + avatar + search)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              8,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting row
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              height: 1.1,
                              letterSpacing: -0.6,
                            ),
                            children: [
                              const TextSpan(text: 'Ciao, '),
                              TextSpan(
                                text: displayName,
                                style: AppTheme.displayNumber(size: 28)
                                    .copyWith(color: AppColors.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/home/profile'),
                        child: profileAsync.maybeWhen(
                          data: (p) => _AvatarWidget(profile: p),
                          orElse: () => const _AvatarPlaceholder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Trova un raduno vicino a te',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.inkMuted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search bar
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.inkSubtle, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Cerca raduni, club, modelli…',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.inkSubtle,
                              ),
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 18,
                              color: AppColors.divider),
                          const SizedBox(width: 10),
                          const Icon(Icons.tune,
                              color: AppColors.inkMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Tutti',
                    selected: filter == HomeFilter.tutti,
                    onTap: () => ref.read(homeFilterProvider.notifier).state =
                        HomeFilter.tutti,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Questa settimana',
                    selected: filter == HomeFilter.settimana,
                    onTap: () => ref.read(homeFilterProvider.notifier).state =
                        HomeFilter.settimana,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Gratuiti',
                    selected: filter == HomeFilter.gratuiti,
                    onTap: () => ref.read(homeFilterProvider.notifier).state =
                        HomeFilter.gratuiti,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'A pagamento',
                    selected: filter == HomeFilter.pagamento,
                    onTap: () => ref.read(homeFilterProvider.notifier).state =
                        HomeFilter.pagamento,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Content (based on location state)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: position.when(
                loading: () => const _SectionHeader(
                  title: 'Vicino a te',
                  subtitle: 'Ricerca posizione…',
                ),
                error: (_, __) => const _SectionHeader(
                  title: 'Raduni in Italia',
                  subtitle: 'Posizione non disponibile',
                ),
                data: (pos) => _SectionHeader(
                  title: 'Vicino a te',
                  onSeeAll: () => context.go('/home/map'),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Raduni list
          position.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: LoadingIndicator(),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _FallbackList(filter: filter, onApplyFilter: _applyFilter),
            ),
            data: (pos) {
              final raduniAsync = ref.watch(raduniNearbyProvider(NearbyParams(
                lat: pos.latitude,
                lng: pos.longitude,
              )));
              return raduniAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: LoadingIndicator(),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(raduniNearbyProvider),
                  ),
                ),
                data: (list) {
                  final filtered = _applyFilter(list, filter);
                  if (filtered.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyView(
                        icon: Icons.event_busy,
                        title: 'Nessun raduno vicino',
                        subtitle: 'Prova ad allargare i criteri di ricerca.',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => RadunoCard(
                        raduno: filtered[i],
                        onTap: () =>
                            context.push('/home/raduni/${filtered[i].id}'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Fallback when position is unavailable — shows all published raduni
class _FallbackList extends ConsumerWidget {
  final HomeFilter filter;
  final List<Raduno> Function(List<Raduno>, HomeFilter) onApplyFilter;
  const _FallbackList({required this.filter, required this.onApplyFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(raduniListStreamProvider).when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(error: e),
      data: (list) {
        final filtered = onApplyFilter(list, filter);
        if (filtered.isEmpty) {
          return const EmptyView(
            icon: Icons.event_busy,
            title: 'Nessun raduno disponibile',
          );
        }
        return Column(
          children: filtered
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RadunoCard(
                    raduno: r,
                    onTap: () => context.push('/home/raduni/${r.id}'),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  final Profile? profile;
  const _AvatarWidget({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile?.avatarUrl != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(profile!.avatarUrl!),
      );
    }
    return const _AvatarPlaceholder();
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.surfaceMuted,
      child: Icon(Icons.person_outline, color: AppColors.inkMuted, size: 22),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.inkSubtle),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Vedi mappa',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
