import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/tm_card.dart';
import '../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _comingSoon = [
    'Tvoja permanentka v mobile',
    'Rebríček osobných rekordov',
    'Súkromie a nastavenia účtu',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PROFIL', style: text.headlineMedium),
            const SizedBox(height: 16),
            if (user != null)
              TmCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceHi,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        user.displayName.isEmpty
                            ? '?'
                            : user.displayName[0].toUpperCase(),
                        style: text.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: text.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: text.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          SectionLabel(
                            user.role.label,
                            icon: Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TmCard(
              grid: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Čoskoro tu nájdeš'),
                  const SizedBox(height: 8),
                  for (final item in _comingSoon)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('•  $item', style: text.bodyMedium),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Odhlásiť sa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
