import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/intro/celebration_overlay.dart';
import 'features/intro/intro_animation.dart';

void main() {
  runApp(const ProviderScope(child: RejnoxApp()));
}

class RejnoxApp extends ConsumerWidget {
  const RejnoxApp({super.key, this.webFonts = true});

  /// false vypne sťahovanie fontov (testy).
  final bool webFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Rejnox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(webFonts: webFonts),
      routerConfig: ref.watch(routerProvider),
      // Úvod pri spustení a oslava po prihlásení ležia nad celou appkou.
      builder: (context, child) =>
          IntroGate(child: CelebrationGate(child: child ?? const SizedBox())),
    );
  }
}
