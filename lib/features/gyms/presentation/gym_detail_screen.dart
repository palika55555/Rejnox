import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/gym_actions.dart';
import '../application/user_location.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import 'gym_detail_widgets.dart';
import 'gym_photos.dart';
import 'gym_prices.dart';

/// Detail fitka: fotka, hodnotenie, akcie a informácie.
class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({super.key, required this.gymId});

  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gym = ref.watch(gymByIdProvider(gymId));
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: gym.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _Missing(),
              data: (gym) => gym == null ? const _Missing() : _Detail(gym),
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail(this.gym);

  final Gym gym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(favoriteGymsProvider).contains(gym.id);
    final user = switch (ref.watch(userLocationProvider).value) {
      LocationFound(:final point) => point,
      _ => null,
    };
    final rating = gym.rating;
    final actions = ref.read(externalActionsProvider);

    Future<void> open(Uri url) async {
      final messenger = ScaffoldMessenger.of(context);
      if (!await actions.openUrl(url)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Odkaz sa nepodarilo otvoriť.')),
        );
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(
            gym: gym,
            saved: saved,
            onBack: () => context.canPop() ? context.pop() : context.go('/map'),
            onToggleSaved: () =>
                ref.read(favoriteGymsProvider.notifier).toggle(gym.id),
            onEdit: gym.mine ? () => context.push('/gym/${gym.id}/edit') : null,
            onDelete: gym.mine ? () => _confirmDelete(context, ref) : null,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList.list(
            children: [
              Text(
                gym.name,
                style: text.titleLarge!.copyWith(fontSize: 24, height: 1.15),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: Color(0xFFF0BE2E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rating == null || rating.count == 0
                        ? 'Zatiaľ bez hodnotení'
                        : '${rating.averageLabel} (${rating.countLabel})',
                    style: text.bodyMedium!.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DetailActionTile(
                      icon: Icons.near_me_rounded,
                      label: 'Navigovať',
                      primary: true,
                      onTap: (_) => open(navigationUrl(gym)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DetailActionTile(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Uložené' : 'Uložiť',
                      onTap: (_) => ref
                          .read(favoriteGymsProvider.notifier)
                          .toggle(gym.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DetailActionTile(
                      icon: Icons.ios_share_rounded,
                      label: 'Zdieľať',
                      onTap: (origin) => actions.share(
                        shareText(gym),
                        subject: gym.name,
                        origin: origin,
                      ),
                    ),
                  ),
                  if (gym.website case final website?) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: DetailActionTile(
                        icon: Icons.language_rounded,
                        label: 'Web',
                        onTap: (_) => open(website),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TmCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    DetailInfoRow(
                      icon: Icons.location_on_outlined,
                      text: gym.fullAddress,
                      trailing: user == null
                          ? null
                          : formatDistance(user.distanceKmTo(gym.location)),
                    ),
                    if (gym.openingHours case final hours?)
                      DetailInfoRow(
                        icon: Icons.schedule_rounded,
                        text: hours == 'Nonstop' ? 'Otvorené nonstop' : hours,
                        color: hours == 'Nonstop' ? AppColors.good : null,
                      ),
                    if (gym.tags.isNotEmpty)
                      DetailInfoRow(
                        icon: Icons.fitness_center_rounded,
                        text: gym.tags.join('  •  '),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GymPhotoStrip(gym: gym),
              const SizedBox(height: 16),
              GymRatingCard(
                rating,
                myStars: gym.myStars,
                onRate: (stars) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref.read(gymsProvider.notifier).rate(gym.id, stars);
                  } on ApiError catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
              const SizedBox(height: 16),
              GymPricesCard(gym: gym),
            ],
          ),
        ),
      ],
    );
  }
}

extension on _Detail {
  /// Zmaže vlastné fitko po potvrdení a vráti sa na mapu.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zmazať fitko?'),
        content: Text(
          '${gym.name} zmizne z mapy aj s fotkami, cenníkom a hodnoteniami. '
          'Nedá sa to vrátiť.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nechať'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Zmazať'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(gymsProvider.notifier).delete(gym.id);
      router.go('/map');
      messenger.showSnackBar(
        const SnackBar(content: Text('Fitko je zmazané.')),
      );
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Fotka fitka (alebo náhradný obrázok) s tlačidlami Späť a Uložiť.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.gym,
    required this.saved,
    required this.onBack,
    required this.onToggleSaved,
    this.onEdit,
    this.onDelete,
  });

  final Gym gym;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onToggleSaved;

  /// Len pre autora fitka.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final photo = shownPhotos(gym).firstOrNull;
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            GymPhotoImage(photo)
          else
            const GymPhotoPlaceholder(),
          // Prechod do pozadia, aby nadpis plynulo nadväzoval.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Colors.transparent, AppColors.bg],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Späť',
                    onPressed: onBack,
                  ),
                  const Spacer(),
                  if (onEdit != null) ...[
                    _CircleButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Upraviť fitko',
                      onPressed: onEdit!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onDelete != null) ...[
                    _CircleButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Zmazať fitko',
                      onPressed: onDelete!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _CircleButton(
                    icon: saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    tooltip: saved ? 'Odobrať z uložených' : 'Uložiť',
                    color: saved ? AppColors.error : null,
                    onPressed: onToggleSaved,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.sheet.withValues(alpha: 0.8),
    shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? AppColors.text),
    ),
  );
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Toto fitko sme nenašli.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/map'),
          child: const Text('Späť na mapu'),
        ),
      ],
    ),
  );
}
