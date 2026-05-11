import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auto/presentation/auto_detail_screen.dart';
import '../../features/auto/presentation/my_garage_screen.dart';
import '../../features/auto/presentation/register_auto_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/impostazioni_screen.dart';
import '../../features/profile/presentation/miei_raduni_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/raduni/presentation/create_raduno_screen.dart';
import '../../features/raduni/presentation/home_screen.dart';
import '../../features/raduni/presentation/raduno_detail_screen.dart';
import '../theme/app_colors.dart';

final GlobalKey<NavigatorState> _rootNavKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = AuthRefreshNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loggedIn = session != null;
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login' || loc == '/signup';

      if (loc == '/') return loggedIn ? '/home/raduni' : '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/home/raduni';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home/raduni',
            builder: (_, __) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'create',
                parentNavigatorKey: _rootNavKey,
                builder: (_, __) => const CreateRadunoScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavKey,
                builder: (_, state) =>
                    RadunoDetailScreen(radunoId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/home/map', builder: (_, __) => const MapScreen()),
          GoRoute(
            path: '/home/garage',
            builder: (_, __) => const MyGarageScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavKey,
                builder: (_, __) => const RegisterAutoScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavKey,
                builder: (_, state) =>
                    AutoDetailScreen(autoId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/home/profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'raduni',
                parentNavigatorKey: _rootNavKey,
                builder: (_, __) => const MieiRaduniScreen(),
              ),
              GoRoute(
                path: 'impostazioni',
                parentNavigatorKey: _rootNavKey,
                builder: (_, __) => const ImpostazioniScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  AuthRefreshNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
}

// ─── Shell with pill-shaped bottom nav + center FAB ───────────────────────────

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    ('/home/raduni', Icons.explore_outlined, Icons.explore, 'Scopri'),
    ('/home/map', Icons.map_outlined, Icons.map, 'Mappa'),
    ('/home/garage', Icons.garage_outlined, Icons.garage, 'Garage'),
    ('/home/profile', Icons.person_outline, Icons.person, 'Profilo'),
  ];

  int _indexFor(String loc) {
    for (var i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _indexFor(loc);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: child,
      bottomNavigationBar: _PillNavBar(
        selectedIndex: idx,
        onTabTap: (i) => context.go(_tabs[i].$1),
        onFabTap: () => context.go('/home/raduni/create'),
        tabs: _tabs,
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<(String, IconData, IconData, String)> tabs;
  final ValueChanged<int> onTabTap;
  final VoidCallback onFabTap;

  const _PillNavBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onTabTap,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = max(MediaQuery.of(context).padding.bottom, 12.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bg.withValues(alpha: 0),
            AppColors.bg,
          ],
          stops: const [0, 0.35],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x0F141E19),
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // First 2 tabs
            for (int i = 0; i < 2; i++)
              Expanded(
                child: _NavItem(
                  icon: tabs[i].$2,
                  activeIcon: tabs[i].$3,
                  label: tabs[i].$4,
                  selected: selectedIndex == i,
                  onTap: () => onTabTap(i),
                ),
              ),
            // Center FAB
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: onFabTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
            // Last 2 tabs
            for (int i = 2; i < 4; i++)
              Expanded(
                child: _NavItem(
                  icon: tabs[i].$2,
                  activeIcon: tabs[i].$3,
                  label: tabs[i].$4,
                  selected: selectedIndex == i,
                  onTap: () => onTabTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.inkSubtle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
