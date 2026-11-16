import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/plate_chip.dart';
import '../application/exercise_stats.dart';
import '../data/exercise_catalog.dart';
import '../domain/training_models.dart';
import '../../../core/theme/app_spacing.dart';

/// Otvorí výber cviku. Vráti zvolený cvik alebo null.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  required String selectedId,
  required Map<String, ExerciseHistory> history,
}) => showModalBottomSheet<Exercise>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ExercisePickerSheet(selectedId: selectedId, history: history),
);

/// Výber cviku: hľadanie, filter partií a obľúbené.
class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({
    super.key,
    required this.selectedId,
    required this.history,
  });

  final String selectedId;
  final Map<String, ExerciseHistory> history;

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<ExercisePickerSheet> {
  String _query = '';

  /// null = všetky partie.
  MuscleGroup? _group;
  bool _onlyFavorites = false;

  List<Exercise> _filtered(Set<String> favorites) {
    final q = _query.trim().toLowerCase();
    return [
      for (final e in exerciseCatalog)
        if ((q.isEmpty || e.name.toLowerCase().contains(q)) &&
            (_group == null || e.group == _group) &&
            (!_onlyFavorites || favorites.contains(e.id)))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final favorites = ref.watch(favoriteExercisesProvider);
    final items = _filtered(favorites);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(child: Text('VYBER CVIK', style: text.headlineMedium)),
                IconButton(
                  tooltip: _onlyFavorites ? 'Všetky cviky' : 'Len obľúbené',
                  isSelected: _onlyFavorites,
                  onPressed: () =>
                      setState(() => _onlyFavorites = !_onlyFavorites),
                  icon: const Icon(Icons.star_outline_rounded),
                  selectedIcon: const Icon(
                    Icons.star_rounded,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: TextField(
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Hľadať cvik',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              children: [
                _GroupChip(
                  label: 'Všetko',
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in MuscleGroup.values)
                  _GroupChip(
                    key: ValueKey('group-${g.name}'),
                    label: g.label,
                    plate: g.plate,
                    selected: _group == g,
                    onTap: () => setState(() => _group = g),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Žiadny cvik nezodpovedá filtru.',
                      style: text.bodyMedium!.copyWith(color: AppColors.ink2),
                    ),
                  )
                : ListView.separated(
                    controller: scroll,
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return _ExerciseTile(
                        exercise: e,
                        history: widget.history[e.id],
                        selected: e.id == widget.selectedId,
                        favorite: favorites.contains(e.id),
                        onTap: () => Navigator.pop(context, e),
                        onFavorite: () => ref
                            .read(favoriteExercisesProvider.notifier)
                            .toggle(e.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.plate,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Plate? plate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.text : AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.text : AppColors.border,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (plate != null) ...[
                    PlateDot(plate!, size: 8),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.bg : AppColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.history,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Exercise exercise;
  final ExerciseHistory? history;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best = history?.bestKg;
    final last = history?.last;
    return Material(
      color: selected ? AppColors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              PlateDot(exercise.group.plate, size: 10),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: text.bodyLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      [
                        exercise.group.label,
                        if (last != null)
                          'minule ${last.reps} × ${formatKg(last.weightKg)} kg',
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (best != null)
                Text(
                  'Rekord ${formatKg(best)} kg',
                  style: text.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              IconButton(
                tooltip: favorite ? 'Odobrať z obľúbených' : 'Obľúbený',
                onPressed: onFavorite,
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: favorite ? AppColors.accent : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
