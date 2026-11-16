import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/training/application/workout_session.dart';
import 'app_router.dart';

const _startWorkout = 'start_workout';
const _messages = 'messages';

/// Skratky pri podržaní ikony appky (iOS Quick Actions, Android Shortcuts).
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    _setUp();
  }

  Future<void> _setUp() async {
    const actions = QuickActions();
    try {
      await actions.initialize(_open);
      await actions.setShortcutItems(const [
        ShortcutItem(type: _startWorkout, localizedTitle: 'Začať tréning'),
        ShortcutItem(type: _messages, localizedTitle: 'Správy'),
      ]);
    } on PlatformException catch (e) {
      debugPrint('Skratky appky sa nenastavili: $e');
    } on MissingPluginException catch (e) {
      debugPrint('Skratky appky nie sú dostupné: $e');
    }
  }

  /// Skratka zo studeného štartu čaká, kým sa obnoví prihlásenie.
  String? _pending;

  void _open(String type) {
    if (!mounted) return;
    if (ref.read(authControllerProvider) is! SignedIn) {
      _pending = type;
      ref.listenManual(authControllerProvider, (_, auth) {
        final waiting = _pending;
        if (auth is SignedIn && waiting != null) {
          _pending = null;
          _open(waiting);
        }
      });
      return;
    }
    final router = ref.read(routerProvider);
    switch (type) {
      case _startWorkout:
        router.go('/workout');
        unawaited(ref.read(workoutSessionProvider.notifier).start());
      case _messages:
        router.go('/chat');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
