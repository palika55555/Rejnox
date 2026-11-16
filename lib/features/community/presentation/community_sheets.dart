import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/community_providers.dart';
import 'community_format.dart';
import 'community_glass.dart';
import '../../../core/theme/app_spacing.dart';

/// Spodný panel s formulárom; zatvorí sa po úspešnom odoslaní.
Future<void> showCommunitySheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.sheet.withValues(alpha: 0.96),
      builder: (_) => child,
    );

/// Obal formulára: nadpis, polia a tlačidlo, ktoré počas ukladania čaká.
class _SheetForm extends StatefulWidget {
  const _SheetForm({
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final List<Widget> fields;
  final String submitLabel;

  /// Vráti false, keď formulár nie je platný (panel ostane otvorený).
  final Future<bool> Function() onSubmit;

  @override
  State<_SheetForm> createState() => _SheetFormState();
}

class _SheetFormState extends State<_SheetForm> {
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      if (await widget.onSubmit() && mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e, 'Uložiť sa nepodarilo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            for (final f in widget.fields) ...[
              f,
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.xs),
            PrimaryButton(
              label: _saving ? 'Ukladám…' : widget.submitLabel,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

String? _text(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

/// Pole s dátumom a časom (otvorí výber dátumu, potom času).
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = true,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool withTime;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !context.mounted) return;
    if (!withTime) return onChanged(day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return;
    onChanged(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(withTime ? whenLabel(value) : dayLabel(value)),
      ),
    );
  }
}

DateTime _nextFullHour([int plusHours = 2]) {
  final now = DateTime.now().add(Duration(hours: plusHours));
  return DateTime(now.year, now.month, now.day, now.hour);
}

// ------------------------------------------------------------- príspevok

class NewPostSheet extends ConsumerStatefulWidget {
  const NewPostSheet({super.key});

  @override
  ConsumerState<NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends ConsumerState<NewPostSheet> {
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
    title: 'Nový príspevok',
    submitLabel: 'Zdieľať',
    fields: [
      TextField(
        controller: _body,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        maxLength: 1000,
        decoration: const InputDecoration(
          hintText: 'Podeľ sa o svoj progres, rekord alebo tip…',
        ),
      ),
    ],
    onSubmit: () async {
      final body = _text(_body);
      if (body == null) return false;
      await ref.read(communityActionsProvider).createPost(body);
      return true;
    },
  );
}

// ------------------------------------------------------------ komentáre

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text(_body);
    if (body == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityActionsProvider).addComment(widget.postId, body);
      _body.clear();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e, 'Komentár sa neodoslal.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.postId));
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Text('Komentáre', style: text.titleLarge),
            Expanded(
              child: comments.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Text(errorText(e, 'Komentáre sa nenačítali.')),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          'Zatiaľ bez komentárov. Buď prvý!',
                          style: text.bodyMedium,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          for (final c in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GlassAvatar(c.authorName, size: 36),
                              title: Text(c.authorName),
                              subtitle: Text(c.body),
                              onLongPress: () async {
                                if (!await confirmDelete(context, 'komentár')) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(communityActionsProvider)
                                      .deleteComment(widget.postId, c.id);
                                } on Object catch (e) {
                                  if (context.mounted) {
                                    showCommunityError(
                                      context,
                                      e,
                                      'Zmazať sa nepodarilo.',
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _body,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Napíš komentár…',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Odoslať',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.accent,
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

// ----------------------------------------------------- tréning s parťákom

class NewBuddySheet extends ConsumerStatefulWidget {
  const NewBuddySheet({super.key});

  @override
  ConsumerState<NewBuddySheet> createState() => _NewBuddySheetState();
}

class _NewBuddySheetState extends ConsumerState<NewBuddySheet> {
  final _place = TextEditingController();
  final _focus = TextEditingController();
  final _note = TextEditingController();
  DateTime _when = _nextFullHour();

  @override
  void dispose() {
    _place.dispose();
    _focus.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
    title: 'Hľadám parťáka',
    submitLabel: 'Zverejniť',
    fields: [
      _DateTimeField(
        label: 'Kedy',
        value: _when,
        onChanged: (v) => setState(() => _when = v),
      ),
      TextField(
        controller: _place,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Kde (fitko, park…)'),
      ),
      TextField(
        controller: _focus,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Čo (nohy, beh 10 km…)'),
      ),
      TextField(
        controller: _note,
        maxLength: 300,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Poznámka'),
      ),
    ],
    onSubmit: () async {
      final place = _text(_place);
      if (place == null) {
        showCommunityError(context, 'Vyplň miesto.', 'Vyplň miesto.');
        return false;
      }
      await ref
          .read(communityActionsProvider)
          .createBuddy(
            startsAt: _when,
            place: place,
            focus: _text(_focus),
            note: _text(_note),
          );
      return true;
    },
  );
}

// --------------------------------------------------------------- udalosť

class NewEventSheet extends ConsumerStatefulWidget {
  const NewEventSheet({super.key});

  @override
  ConsumerState<NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends ConsumerState<NewEventSheet> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _description = TextEditingController();
  DateTime _when = _nextFullHour(24);

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
    title: 'Nová udalosť',
    submitLabel: 'Vytvoriť',
    fields: [
      TextField(
        controller: _title,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Názov'),
      ),
      _DateTimeField(
        label: 'Kedy',
        value: _when,
        onChanged: (v) => setState(() => _when = v),
      ),
      TextField(
        controller: _place,
        maxLength: 120,
        decoration: const InputDecoration(labelText: 'Kde'),
      ),
      TextField(
        controller: _description,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Popis'),
      ),
    ],
    onSubmit: () async {
      final title = _text(_title);
      final place = _text(_place);
      if (title == null || place == null) {
        showCommunityError(context, '', 'Vyplň názov a miesto.');
        return false;
      }
      await ref
          .read(communityActionsProvider)
          .createEvent(
            title: title,
            place: place,
            startsAt: _when,
            description: _text(_description),
          );
      return true;
    },
  );
}

// ----------------------------------------------------------------- výzva

class NewChallengeSheet extends ConsumerStatefulWidget {
  const NewChallengeSheet({super.key});

  @override
  ConsumerState<NewChallengeSheet> createState() => _NewChallengeSheetState();
}

class _NewChallengeSheetState extends ConsumerState<NewChallengeSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  late DateTime _end = _start.add(const Duration(days: 29));
  int _goal = 12;

  int get _length => _end.difference(_start).inDays + 1;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxGoal = _length.clamp(1, 366);
    final goal = _goal.clamp(1, maxGoal);
    return _SheetForm(
      title: 'Nová výzva',
      submitLabel: 'Spustiť výzvu',
      fields: [
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Názov'),
        ),
        Row(
          children: [
            Expanded(
              child: _DateTimeField(
                label: 'Od',
                value: _start,
                withTime: false,
                onChanged: (v) => setState(() {
                  _start = v;
                  if (_end.isBefore(v)) _end = v;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DateTimeField(
                label: 'Do',
                value: _end,
                withTime: false,
                onChanged: (v) =>
                    setState(() => _end = v.isBefore(_start) ? _start : v),
              ),
            ),
          ],
        ),
        Text(
          'Cieľ: $goal ${plural(goal, 'deň', 'dni', 'dní')} s tréningom',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider.adaptive(
          value: goal.toDouble(),
          min: 1,
          max: maxGoal.toDouble().clamp(2, 366),
          divisions: maxGoal > 1 ? maxGoal - 1 : 1,
          label: '$goal',
          onChanged: (v) => setState(() => _goal = v.round()),
        ),
        TextField(
          controller: _description,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Popis'),
        ),
      ],
      onSubmit: () async {
        final title = _text(_title);
        if (title == null) {
          showCommunityError(context, '', 'Vyplň názov výzvy.');
          return false;
        }
        await ref
            .read(communityActionsProvider)
            .createChallenge(
              title: title,
              goalDays: goal,
              startsOn: _start,
              endsOn: _end,
              description: _text(_description),
            );
        return true;
      },
    );
  }
}
