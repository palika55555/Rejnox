import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/coaching_providers.dart';
import '../domain/coaching_models.dart';
import 'add_plan_sheet.dart';
import 'client_progress.dart';
import 'coaching_widgets.dart';

/// Detail klienta pre trénera: pozvánka, plány a progres.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(clientDetailProvider(clientId));
    return SafeArea(
      bottom: false,
      child: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorText(e)),
              TextButton(
                onPressed: () => ref.invalidate(clientDetailProvider(clientId)),
                child: const Text('Skúsiť znova'),
              ),
            ],
          ),
        ),
        data: (d) => _Body(d),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.detail);

  final ClientDetail detail;

  ClientLink get client => detail.client;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      final code = await ref.read(clientActionsProvider(client.id)).invite();
      if (context.mounted) await _showCode(context, code);
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _showCode(
    BuildContext context,
    InviteCode code,
  ) => showDialog<void>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Pozývací kód'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pošli ho klientovi. V appke ho zadá v Profile → '
              '„Mám kód od trénera“.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            SelectableText(
              code.code,
              style: text.headlineLarge!.copyWith(
                letterSpacing: 4,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Platí do ${formatDay(code.expiresAt)}. '
              'Kód sa zobrazí len teraz.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                // Prehliadač môže schránku zakázať; kód je aj tak na očiach.
                await Clipboard.setData(
                  ClipboardData(text: code.code),
                ).timeout(const Duration(seconds: 2));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Kód je skopírovaný.')),
                );
              } on Object {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Kopírovanie nejde, prepíš kód ručne.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Kopírovať'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hotovo'),
          ),
        ],
      );
    },
  );

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Ukončiť spoluprácu?',
      message:
          'Stratíš prístup k plánom a progresu klienta. '
          'Klientovi jeho história ostane.',
      confirmLabel: 'Ukončiť',
    );
    if (ok && context.mounted) {
      await _run(context, ref.read(clientActionsProvider(client.id)).end);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Zmazať klienta?',
      message: 'Zmažú sa aj jeho plány a série. Nedá sa to vrátiť.',
      confirmLabel: 'Zmazať',
    );
    if (!ok || !context.mounted) return;
    await _run(context, () async {
      await ref.read(clientActionsProvider(client.id)).delete();
      if (context.mounted) context.go('/clients');
    });
  }

  Future<void> _deletePlan(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Zmazať plán?',
      message: 'Plán „${plan.title}“ zmizne aj klientovi.',
      confirmLabel: 'Zmazať',
    );
    if (ok && context.mounted) {
      await _run(
        context,
        () => ref.read(clientActionsProvider(client.id)).deletePlan(plan.id),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(clientDetailProvider(client.id).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Späť na klientov',
                onPressed: () => context.go('/clients'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  client.name.toUpperCase(),
                  style: text.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LinkStatusChip(client.status),
            ],
          ),
          if (client.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(client.note!, style: text.bodyMedium),
            ),
          const SizedBox(height: 14),
          _AccountCard(
            client: client,
            onInvite: () => _invite(context, ref),
            onEnd: () => _end(context, ref),
            onDelete: () => _delete(context, ref),
          ),
          if (client.isActive) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: SectionLabel('Plány', icon: Icons.assignment_rounded),
                ),
                TextButton.icon(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    builder: (_) => AddPlanSheet(clientId: client.id),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nový plán'),
                ),
              ],
            ),
            if (detail.plans.isEmpty)
              Text('Zatiaľ žiadny plán.', style: text.bodySmall),
            for (final p in detail.plans) ...[
              PlanCard(p, onDelete: () => _deletePlan(context, ref, p)),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            LogClientSetCard(clientId: client.id),
            const SizedBox(height: 12),
            ClientProgressCard(detail.sets),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.client,
    required this.onInvite,
    required this.onEnd,
    required this.onDelete,
  });

  final ClientLink client;
  final VoidCallback onInvite;
  final VoidCallback onEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final expires = client.inviteExpiresAt;
    final message = switch (client.status) {
      LinkStatus.recordOnly =>
        'Klient appku nemá. Plány a progres mu môžeš viesť aj tak.',
      LinkStatus.invited =>
        'Pozvánka čaká${expires == null ? '' : ' do ${formatDay(expires)}'}. '
            'Ak kód stratil, vytvor nový.',
      LinkStatus.linked => 'Klient je prepojený a vidí plány v appke.',
      LinkStatus.ended =>
        'Spolupráca je ukončená. K údajom klienta už nemáš prístup.',
    };
    return TmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: text.bodyMedium),
          if (client.canInvite) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: client.status == LinkStatus.invited
                  ? 'Vytvoriť nový kód'
                  : 'Pozvať do appky',
              icon: Icons.qr_code_2_rounded,
              onPressed: onInvite,
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (client.isActive)
                TextButton(
                  onPressed: onEnd,
                  child: const Text('Ukončiť spoluprácu'),
                ),
              if (!client.hasAccount)
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: Plate.red.color),
                  child: const Text('Zmazať klienta'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
