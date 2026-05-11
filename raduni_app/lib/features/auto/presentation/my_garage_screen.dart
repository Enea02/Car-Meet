import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../data/auto_model.dart';
import '../providers/auto_providers.dart';

class MyGarageScreen extends ConsumerWidget {
  const MyGarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(myGarageProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: garage.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(myGarageProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyGarage(
              onAdd: () => context.go('/home/garage/add'),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(myGarageProvider);
              await ref.read(myGarageProvider.future);
            },
            child: _GarageContent(
              autos: list,
              onAdd: () => context.go('/home/garage/add'),
              onTap: (id) => context.go('/home/garage/$id'),
            ),
          );
        },
      ),
    );
  }
}

class _GarageContent extends StatelessWidget {
  final List<Auto> autos;
  final VoidCallback onAdd;
  final ValueChanged<String> onTap;

  const _GarageContent({
    required this.autos,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hero = autos.first;
    final secondary = autos.skip(1).toList();

    return CustomScrollView(
      slivers: [
        // ── Header safe area
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
        ),

        // ── Title row
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Il mio garage',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                // Add button
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Hero auto
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: _HeroCard(auto: hero, onTap: () => onTap(hero.id)),
          ),
        ),

        // ── Secondary grid
        if (secondary.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Le tue altre auto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: secondary
                  .map((a) => _GridCard(auto: a, onTap: () => onTap(a.id)))
                  .toList(),
            ),
          ),
        ] else ...[
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Auto auto;
  final VoidCallback onTap;
  const _HeroCard({required this.auto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              auto.photoUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: auto.photoUrls.first,
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

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.4, 1],
                    ),
                  ),
                ),
              ),

              // Label overlay
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (auto.year != null)
                      Text(
                        '${auto.year}',
                        style: AppTheme.mono(
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          weight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      '${auto.make} ${auto.model}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // "Principale" badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Principale',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final Auto auto;
  final VoidCallback onTap;
  const _GridCard({required this.auto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            auto.photoUrls.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: auto.photoUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.surfaceMuted),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.surfaceMuted),
                  )
                : Container(
                    color: AppColors.surfaceMuted,
                    child: const Icon(Icons.directions_car_outlined,
                        size: 36, color: AppColors.inkSubtle),
                  ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                '${auto.make} ${auto.model}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGarage({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.garage_outlined,
                  size: 40, color: AppColors.inkSubtle),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nessuna auto nel garage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aggiungine una per esporla ai raduni.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi auto'),
            ),
          ],
        ),
      ),
    );
  }
}
