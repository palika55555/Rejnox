import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/coaching_providers.dart';
import '../domain/coaching_models.dart';
import 'coaching_widgets.dart';

/// Profil klienta: moji tréneri a zadanie pozývacieho kódu.
class MyTrainerCard extends ConsumerWidget {
  const MyTrainerCard({super.key});

  Future<void> _enterCode(BuildContext context, WidgetRef ref) async {
    final trainer = await showDialog<MyTrainer>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (trainer != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Si prepojený s trénerom ${trainer.trainerName}.'),
        ),
      );
    }
  }

  Future<void> _end(BuildContext context, WidgetRef ref, MyTrainer t) async {
    final ok = await confirmAction(
      context,
      title: 'Ukončiť spoluprácu?',
      message:
          '${t.trainerName} už neuvidí tvoje plány ani progres. '
          'Tvoja história ti ostane.',
      confirmLabel: 'Ukončiť',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(myTrainersProvider.notifier).end(t.linkId);
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final trainers = ref.watch(myTrainersProvider);
    final active = [
      for (final t in trainers.value ?? const <MyTrainer>[])
        if (t.status == LinkStatus.linked) t,
    ];

    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Môj tréner', icon: Icons.sports_rounded),
          const SizedBox(height: 10),
          if (trainers.isLoading && !trainers.hasValue)
            const Center(child: CircularProgressIndicator())
          else if (trainers.hasError && !trainers.hasValue)
            Text(errorText(trainers.error!), style: text.bodySmall)
          else if (active.isEmpty)
            Text(
              'Zatiaľ nemáš trénera. Ak ti tréner dal kód, zadaj ho nižšie.',
              style: text.bodyMedium,
            ),
          for (final t in active)
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.actionGradient,
                  ),
                  child: Text(
                    t.trainerName.isEmpty
                        ? '?'
                        : t.trainerName[0].toUpperCase(),
                    style: text.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(t.trainerName, style: text.titleMedium)),
                TextButton(
                  onPressed: () => _end(context, ref, t),
                  child: const Text('Ukončiť'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Mám kód od trénera',
            icon: Icons.key_rounded,
            onPressed: () => _enterCode(context, ref),
          ),
        ],
      ),
    );
  }
}

class _CodeDialog extends ConsumerStatefulWidget {
  const _CodeDialog();

  @override
  ConsumerState<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends ConsumerState<_CodeDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != 8) {
      setState(() => _error = 'Kód má 8 znakov, napr. K7QM-4XPA.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final trainer = await ref
          .read(myTrainersProvider.notifier)
          .acceptCode(code);
      if (mounted) Navigator.pop(context, trainer);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Kód od trénera'),
      content: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        maxLength: 9,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'XXXX-XXXX',
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Overujem…' : 'Prepojiť'),
        ),
      ],
    );
  }
}
