import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/tm_card.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';
import '../../../core/theme/app_spacing.dart';

/// Cenník fitka od používateľov: permanentky a produkty.
class GymPricesCard extends ConsumerWidget {
  const GymPricesCard({super.key, required this.gym});

  final Gym gym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> delete(GymPrice price) async {
      try {
        await ref.read(gymsProvider.notifier).deletePrice(price.id);
      } on ApiError catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    return TmCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cenník', style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          if (gym.prices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
              ),
              child: Text(
                'Ceny zatiaľ nikto nezadal. Poznáš ich? Pridaj ich ostatným.',
                style: text.bodyMedium!.copyWith(color: AppColors.muted),
              ),
            ),
          for (final kind in GymPriceKind.values)
            if (gym.prices.any((p) => p.kind == kind)) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xxs,
                ),
                child: Text(
                  kind.label,
                  style: text.bodySmall!.copyWith(color: AppColors.ink2),
                ),
              ),
              for (final price in gym.prices)
                if (price.kind == kind)
                  _PriceRow(
                    price: price,
                    onDelete: price.mine ? () => delete(price) : null,
                  ),
            ],
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.sheet,
              builder: (_) => AddPriceSheet(gymId: gym.id),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Pridať cenu'),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price, required this.onDelete});

  final GymPrice price;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    final period = price.period;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: price.title,
                children: [
                  if (period != null)
                    TextSpan(
                      text: '  · $period',
                      style: style.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
              style: style,
            ),
          ),
          Text(
            price.priceLabel,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Zmazať moju cenu',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            )
          else
            const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Formulár novej ceny (spodný panel).
class AddPriceSheet extends ConsumerStatefulWidget {
  const AddPriceSheet({super.key, required this.gymId});

  final String gymId;

  @override
  ConsumerState<AddPriceSheet> createState() => _AddPriceSheetState();
}

class _AddPriceSheetState extends ConsumerState<AddPriceSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _period = TextEditingController();
  var _kind = GymPriceKind.membership;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _period.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final period = _period.text.trim();
      await ref
          .read(gymsProvider.notifier)
          .addPrice(
            widget.gymId,
            kind: _kind,
            title: _title.text.trim(),
            priceCents: parsePriceCents(_price.text)!,
            period: period.isEmpty ? null : period,
          );
      navigator.pop();
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = _kind == GymPriceKind.membership;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nová cena', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<GymPriceKind>(
              segments: const [
                ButtonSegment(
                  value: GymPriceKind.membership,
                  label: Text('Vstup / permanentka'),
                ),
                ButtonSegment(
                  value: GymPriceKind.product,
                  label: Text('Produkt'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Názov',
                hintText: membership
                    ? 'Jednorazový vstup, Mesačná permanentka…'
                    : 'Proteínový nápoj, Uterák…',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Zadaj názov.' : null,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cena',
                      suffixText: '€',
                    ),
                    validator: (v) => parsePriceCents(v ?? '') == null
                        ? 'Napr. 39 alebo 4,50'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _period,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: 'Obdobie (nepovinné)',
                      hintText: membership ? 'mesiac, 10 vstupov' : 'kus',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Ukladám…' : 'Pridať do cenníka'),
            ),
          ],
        ),
      ),
    );
  }
}
