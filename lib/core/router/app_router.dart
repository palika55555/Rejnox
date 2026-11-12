import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/coaching/presentation/client_detail_screen.dart';
import '../../features/coaching/presentation/clients_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/training/presentation/workout_log_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/rejnox_mark.dart';

const _authPaths = {'/login', '/register'};

/// Kam presmerovať podľa stavu prihlásenia (null = nikam).
String? authRedirect(AuthState auth, String location) => switch (auth) {
  AuthRestoring() => location == '/splash' ? null : '/splash',
  SignedOut() => _authPaths.contains(location) ? null : '/login',
  SignedIn() =>
    location == '/splash' || _authPaths.contains(location) ? '/home' : null,
};

final routerProvider = Provider<GoRouter>((ref) {
  // Router sa pri zmene prihlásenia znova rozhodne, kam patrí.
  final authState = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => authState.value = next);

  StatefulShellBranch branch(String path, Widget screen) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => screen)],
  );

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: authState,
    redirect: (context, state) =>
        authRedirect(authState.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _Splash()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthScreen(register: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          branch('/home', const HomeScreen()),
          branch(
            '/map',
            const PlaceholderScreen(
              title: 'Mapa fitiek',
              icon: Icons.map_outlined,
              features: [
                'Fitká v okolí na mape',
                'Cenník permanentiek a produktov od používateľov',
                'Kto hľadá parťáka na tréning',
              ],
            ),
          ),
          branch('/workout', const WorkoutLogScreen()),
          branch(
            '/chat',
            const PlaceholderScreen(
              title: 'Správy',
              icon: Icons.chat_bubble_outline_rounded,
              features: [
                'Chat s trénerom',
                'Chat s ostatnými cvičiacimi',
                'Rezervácia termínov u trénera',
              ],
            ),
          ),
          branch('/profile', const ProfileScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authState.dispose();
  });
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const AppBackground(
    child: Scaffold(body: Center(child: RejnoxMark(width: 80))),
  );
}
