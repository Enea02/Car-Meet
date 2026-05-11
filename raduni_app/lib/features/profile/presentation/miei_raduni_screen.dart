import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/raduno_card.dart';
import '../../raduni/data/raduno_model.dart';
import '../../raduni/providers/raduni_providers.dart';

class MieiRaduniScreen extends ConsumerStatefulWidget {
  const MieiRaduniScreen({super.key});

  @override
  ConsumerState<MieiRaduniScreen> createState() => _MieiRaduniScreenState();
}

class _MieiRaduniScreenState extends ConsumerState<MieiRaduniScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('I miei raduni'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.accent,
          dividerColor: AppColors.divider,
          tabs: const [
            Tab(text: 'Parteciperò'),
            Tab(text: 'Organizzo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _AttendedList(),
          _OrganizedList(),
        ],
      ),
    );
  }
}

// ── Lista raduni a cui parteciperò ───────────────────────────────────────────

class _AttendedList extends ConsumerWidget {
  const _AttendedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAttendedRaduniProvider);
    return async.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(myAttendedRaduniProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            icon: Icons.event_outlined,
            title: 'Nessun raduno',
            subtitle: 'Iscriviti a un raduno dalla home.',
          );
        }
        return _RaduniList(
          raduni: list,
          onRefresh: () async => ref.invalidate(myAttendedRaduniProvider),
        );
      },
    );
  }
}

// ── Lista raduni che organizzo ────────────────────────────────────────────────

class _OrganizedList extends ConsumerWidget {
  const _OrganizedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myOrganizedRaduniProvider);
    return async.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(myOrganizedRaduniProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyView(
            icon: Icons.add_circle_outline,
            title: 'Nessun raduno organizzato',
            subtitle: 'Crea il tuo primo raduno con il + in basso.',
            action: FilledButton.icon(
              onPressed: () => context.go('/home/raduni/create'),
              icon: const Icon(Icons.add),
              label: const Text('Crea raduno'),
            ),
          );
        }
        return _RaduniList(
          raduni: list,
          onRefresh: () async => ref.invalidate(myOrganizedRaduniProvider),
        );
      },
    );
  }
}

// ── Lista comune ─────────────────────────────────────────────────────────────

class _RaduniList extends StatelessWidget {
  final List<Raduno> raduni;
  final Future<void> Function() onRefresh;
  const _RaduniList({required this.raduni, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = raduni.where((r) => r.startAt.isAfter(now)).toList();
    final past = raduni.where((r) => !r.startAt.isAfter(now)).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          if (upcoming.isNotEmpty) ...[
            const _SectionTitle('Prossimi'),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: upcoming.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => RadunoCard(
                  raduno: upcoming[i],
                  onTap: () => context.push('/home/raduni/${upcoming[i].id}'),
                ),
              ),
            ),
          ],
          if (past.isNotEmpty) ...[
            _SectionTitle(
                upcoming.isEmpty ? 'Passati' : 'Passati',
                color: AppColors.inkSubtle),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.separated(
                itemCount: past.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Opacity(
                  opacity: 0.6,
                  child: RadunoCard(
                    raduno: past[i],
                    onTap: () => context.push('/home/raduni/${past[i].id}'),
                  ),
                ),
              ),
            ),
          ],
          if (upcoming.isEmpty && past.isEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color? color;
  const _SectionTitle(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
