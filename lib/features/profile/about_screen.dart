import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/rejnox_mark.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/widgets/tm_card.dart';
import '../gyms/application/gym_actions.dart';
import '../gyms/presentation/map_style.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppBackground(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                'O aplikácii',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/profile');
                  }
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SectionStack(
                        children: [
                          TmCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const ExcludeSemantics(
                                      child: RejnoxMark(width: 48),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'REJNOX',
                                        style: text.headlineLarge,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Rejnox je tréningový denník a mapa fitiek. Zapisuj si série aj bez internetu, sleduj svoj progres a cvič podľa plánov od trénera.',
                                ),
                              ],
                            ),
                          ),
                          AppSection(
                            title: 'Mapové podklady',
                            child: AppList(
                              children: [
                                AppRow(
                                  leading: const Icon(
                                    Icons.map_outlined,
                                    color: AppColors.accent,
                                  ),
                                  title: MapStyle.attribution,
                                  subtitle:
                                      'Licencia Open Database License (ODbL)',
                                  trailing: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 20,
                                  ),
                                  onTap: () async {
                                    final opened = await ref
                                        .read(externalActionsProvider)
                                        .openUrl(MapStyle.attributionUrl);
                                    if (!opened && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Odkaz sa nepodarilo otvoriť.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
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
        ),
      ),
    );
  }
}
