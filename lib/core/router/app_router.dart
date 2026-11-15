import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/body/presentation/body_screen.dart';
import '../../features/booking/presentation/client_calendar_screen.dart';
import '../../features/booking/presentation/trainer_calendar_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/coaching/presentation/client_detail_screen.dart';
import '../../features/coaching/presentation/clients_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/gyms/domain/gym.dart';
import '../../features/gyms/presentation/gym_detail_screen.dart';
import '../../features/gyms/presentation/gym_form_screen.dart';
import '../../features/gyms/presentation/gym_map_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/health/heart_rate_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/about_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/training/presentation/workout_log_screen.dart';
import '../widgets/app_background.dart';
import '../widgets/rejnox_mark.dart';

const _authPaths = {'/welcome', '/login', '/register'};

/// Kam presmerovať podľa stavu prihlásenia (null = nikam).
String? authRedirect(AuthState auth, String location) => switch (auth) {
  AuthRestoring() => location == '/splash' ? null : '/splash',
  SignedOut() => _authPaths.contains(location) ? null : '/welcome',
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
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthScreen(register: true),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/health',
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(path: '/body', builder: (context, state) => const BodyScreen()),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const TrainerCalendarScreen(),
      ),
      GoRoute(
        path: '/trainer/:id/calendar',
        builder: (context, state) =>
            ClientCalendarScreen(linkId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatScreen(
          linkId: state.pathParameters['id']!,
          name: state.extra is String ? state.extra! as String : null,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: '/heart-rate',
        builder: (context, state) => const HeartRateScreen(),
      ),
      // Pred /gym/:id, aby sa „new“ nebralo ako ID fitka.
      GoRoute(
        path: '/gym/new',
        builder: (context, state) => GymFormScreen(
          initialLocation: geoPointFromQuery(state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/gym/:id/edit',
        builder: (context, state) =>
            GymFormScreen(gymId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/gym/:id',
        builder: (context, state) =>
            GymDetailScreen(gymId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          branch('/home', const HomeScreen()),
          branch('/map', const GymMapScreen()),
          branch('/workout', const WorkoutLogScreen()),
          branch('/chat', const ChatsScreen()),
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
          branch('/community', const CommunityScreen()),
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
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(child: RejnoxLoader()),
    ),
  );
}
