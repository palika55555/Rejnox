import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import 'community_format.dart';
import 'community_glass.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/skeleton.dart';

/// Zoznam zo servera: načítavanie, chyba s „Skúsiť znova“, prázdny stav
/// a potiahnutie na obnovenie.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.isEmpty,
    required this.empty,
    required this.builder,
    this.header = const [],
  });

  final AsyncValue<T> value;
  final VoidCallback onRefresh;
  final bool Function(T data) isEmpty;
  final Widget empty;
  final List<Widget> Function(T data) builder;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    // Pri obnovení ostanú staré údaje, kým neprídu nové.
    final current = value;
    final children = switch (current) {
      _ when current.hasValue =>
        isEmpty(current.requireValue) ? [empty] : builder(current.requireValue),
      AsyncError(:final error) => [
        _ErrorCard(
          message: errorText(error, 'Nepodarilo sa načítať údaje.'),
          onRetry: onRefresh,
        ),
      ],
      _ => [const SkeletonList(count: 4)],
    };
    return RefreshIndicator.adaptive(
      color: AppColors.accent,
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          110,
        ),
        children: [
          for (final (i, w) in [...header, ...children].indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Appear(index: i, child: w),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Skúsiť znova',
            compact: true,
            tone: ButtonTone.ghost,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
