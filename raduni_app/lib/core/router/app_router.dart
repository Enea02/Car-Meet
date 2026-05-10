import 'dart:async';

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
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/raduni/presentation/create_raduno_screen.dart';
import '../../features/raduni/presentation/home_screen.dart';
import '../../features/raduni/presentation/raduno_detail_screen.dart';

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
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    ('/home/raduni', Icons.event, 'Raduni'),
    ('/home/map', Icons.map_outlined, 'Mappa'),
    ('/home/garage', Icons.garage_outlined, 'Garage'),
    ('/home/profile', Icons.person_outline, 'Profilo'),
  ];

  int _indexFromLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.$2), label: tab.$3),
        ],
      ),
    );
  }
}
