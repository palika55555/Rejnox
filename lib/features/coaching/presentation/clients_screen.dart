import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/coaching_providers.dart';
import '../domain/coaching_models.dart';
import 'coaching_widgets.dart';

/// Zoznam klientov trénera.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<ClientLink>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _AddClientSheet(),
    );
    if (created != null && context.mounted) {
      context.go('/clients/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final clients = ref.watch(clientsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(clientsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Row(
              children: [
                Expanded(child: Text('KLIENTI', style: text.headlineMedium)),
                PrimaryButton(
                  label: 'Pridať',
                  icon: Icons.person_add_alt_1_rounded,
                  compact: true,
                  onPressed: () => _add(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...clients.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                TmCard(
                  child: Column(
                    children: [
                      Text(errorText(e), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(clientsProvider),
                        child: const Text('Skúsiť znova'),
                      ),
                    ],
                  ),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      TmCard(
                        grid: true,
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Zatiaľ nemáš klientov. Pridaj prvého – stačí meno, '
                          'appku mať nemusí.',
                          style: text.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  : [
                      for (final c in list) ...[
                        _ClientTile(c),
                        const SizedBox(height: 10),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile(this.client);

  final ClientLink client;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TmCard(
      onTap: () => context.go('/clients/${client.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceHi,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              client.name.isEmpty ? '?' : client.name[0].toUpperCase(),
              style: text.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (client.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    client.note!,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          LinkStatusChip(client.status),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _AddClientSheet extends ConsumerStatefulWidget {
  const _AddClientSheet();

  @override
  ConsumerState<_AddClientSheet> createState() => _AddClientSheetState();
}

class _AddClientSheetState extends ConsumerState<_AddClientSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final client = await ref
          .read(clientsProvider.notifier)
          .add(name: _name.text.trim(), note: _note.text.trim());
      if (mounted) Navigator.pop(context, client);
    } on Object catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('NOVÝ KLIENT', style: text.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Klient nemusí mať appku. Pozvať ho môžeš hneď alebo neskôr.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Meno a priezvisko'),
              validator: (v) {
                final name = (v ?? '').trim();
                return name.isEmpty || name.length > 60
                    ? 'Zadaj meno (najviac 60 znakov).'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Poznámka (nepovinné)',
                hintText: 'Napr. ciele, zranenia',
              ),
              validator: (v) =>
                  (v ?? '').trim().length > 500 ? 'Najviac 500 znakov.' : null,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _busy ? 'Ukladám…' : 'Pridať klienta',
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
