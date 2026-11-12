import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/tm_card.dart';
import '../auth/domain/auth_models.dart';
import '../auth/presentation/auth_controller.dart';

/// Rám appky: žiariace pozadie, obsah a plávajúca spodná navigácia.
/// Na webe drží šírku telefónu.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Poradie vetiev v routeri: 0 Domov, 1 Mapa, 2 Tréning, 3 Správy,
  /// 4 Profil, 5 Klienti (len tréner).
  static const _member = [
    (branch: 0, icon: Icons.home_rounded, label: 'Domov'),
    (branch: 1, icon: Icons.map_outlined, label: 'Mapa'),
    (branch: 2, icon: Icons.fitness_center_rounded, label: 'Tréning'),
    (branch: 3, icon: Icons.chat_bubble_outline_rounded, label: 'Správy'),
    (branch: 4, icon: Icons.person_outline_rounded, label: 'Profil'),
  ];
  static const _trainer = [
    (branch: 0, icon: Icons.home_rounded, label: 'Domov'),
    (branch: 5, icon: Icons.groups_rounded, label: 'Klienti'),
    (branch: 2, icon: Icons.fitness_center_rounded, label: 'Tréning'),
    (branch: 3, icon: Icons.chat_bubble_outline_rounded, label: 'Správy'),
    (branch: 4, icon: Icons.person_outline_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isTrainer = auth is SignedIn && auth.user.role == UserRole.trainer;
    final items = isTrainer ? _trainer : _member;
    final current = items.indexWhere((i) => i.branch == shell.currentIndex);

    return AppBackground(
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(child: shell),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _NavBar(
                    items: [
                      for (final i in items) (icon: i.icon, label: i.label),
                    ],
                    current: current,
                    onTap: (index) {
                      final branch = items[index].branch;
                      shell.goBranch(
                        branch,
                        initialLocation: branch == shell.currentIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.items,
    required this.current,
    required this.onTap,
  });

  final List<({IconData icon, String label})> items;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == current,
                button: true,
                child: InkResponse(
                  onTap: () => onTap(i),
                  radius: 32,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: i == current
                                ? AppColors.actionGradient
                                : null,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: i == current
                                ? [
                                    BoxShadow(
                                      color: AppColors.violet.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            items[i].icon,
                            size: 20,
                            color: i == current
                                ? Colors.white
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: text.bodySmall!.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: i == current
                                ? AppColors.text
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dočasná obrazovka pre časti, ktoré ešte nie sú postavené.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.features,
  });

  final String title;
  final IconData icon;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(), style: text.headlineMedium),
            const SizedBox(height: 16),
            TmCard(
              grid: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 32, color: AppColors.accent),
                  const SizedBox(height: 12),
                  const SectionLabel('Čoskoro tu nájdeš'),
                  const SizedBox(height: 10),
                  for (final feature in features)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.violet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(feature, style: text.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
