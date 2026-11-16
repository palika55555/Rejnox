import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/tm_card.dart';
import '../application/chat_actions.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';

enum NewChatMode {
  /// Ťuk na človeka otvorí súkromnú konverzáciu.
  direct,

  /// Názov a výber ľudí, potom „Vytvoriť skupinu“.
  group,

  /// Pridanie ľudí do existujúcej skupiny.
  addMembers,
}

/// Výber ľudí z kontaktov (tréner, klienti, ľudia zo spoločných skupín).
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({
    super.key,
    this.mode = NewChatMode.direct,
    this.groupId,
    this.existing = const {},
  });

  final NewChatMode mode;

  /// Skupina, do ktorej sa pridáva (pri [NewChatMode.addMembers]).
  final String? groupId;

  /// Kto už v skupine je (v zozname sa neukáže).
  final Set<String> existing;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _title = TextEditingController();
  final _selected = <String>{};
  String _query = '';
  bool _busy = false;

  bool get _picking => widget.mode != NewChatMode.direct;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } on Object catch (e) {
      if (mounted) showChatError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDirect(ChatContact contact) => _run(() async {
    final id = await ref.read(chatActionsProvider).openDirect(contact.id);
    if (!mounted) return;
    context.pushReplacement('/conversation/$id', extra: contact.name);
  });

  void _submit() => _run(() async {
    final actions = ref.read(chatActionsProvider);
    if (widget.mode == NewChatMode.group) {
      final id = await actions.createGroup(_title.text, _selected.toList());
      if (mounted) context.pushReplacement('/conversation/$id');
    } else {
      await actions.addMembers(widget.groupId!, _selected.toList());
      if (mounted) context.pop();
    }
  });

  bool get _canSubmit => switch (widget.mode) {
    NewChatMode.group => _title.text.trim().isNotEmpty,
    NewChatMode.addMembers => _selected.isNotEmpty,
    NewChatMode.direct => false,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final contacts = ref.watch(chatContactsProvider);
    final title = switch (widget.mode) {
      NewChatMode.direct => 'Nová správa',
      NewChatMode.group => 'Nová skupina',
      NewChatMode.addMembers => 'Pridať ľudí',
    };
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title,
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/chat'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.mode == NewChatMode.group) ...[
                          TextField(
                            controller: _title,
                            maxLength: 60,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Názov skupiny',
                              hintText: 'napr. Ranný beh',
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            hintText: 'Hľadať',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: contacts.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ChatEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: chatErrorText(e),
                        action: TextButton(
                          onPressed: () => ref.invalidate(chatContactsProvider),
                          child: const Text('Skúsiť znova'),
                        ),
                      ),
                      data: (all) {
                        final q = _query.trim().toLowerCase();
                        final list = [
                          for (final c in all)
                            if (!widget.existing.contains(c.id) &&
                                (q.isEmpty || c.name.toLowerCase().contains(q)))
                              c,
                        ];
                        if (list.isEmpty) {
                          return ChatEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: all.isEmpty
                                ? 'Zatiaľ nemáš komu písať'
                                : 'Nikto ďalší',
                            body: all.isEmpty
                                ? 'Písať môžeš svojmu trénerovi alebo klientom '
                                      'a ľuďom zo spoločných skupín. Do skupiny '
                                      'sa dá pridať aj pozývacím kódom.'
                                : null,
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          children: [
                            if (widget.mode == NewChatMode.group)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Vyber ľudí (môžeš aj neskôr, alebo pošli '
                                  'pozývací kód).',
                                  style: text.bodySmall!.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            AppList(
                              children: [
                                for (final c in list)
                                  AppRow(
                                    leading: ChatAvatar(c.name, size: 36),
                                    title: c.name,
                                    subtitle: c.isTrainer ? 'Tréner' : null,
                                    trailing: _picking
                                        ? Checkbox(
                                            value: _selected.contains(c.id),
                                            onChanged: (_) => _toggle(c.id),
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.muted,
                                          ),
                                    onTap: _busy
                                        ? null
                                        : _picking
                                        ? () => _toggle(c.id)
                                        : () => _openDirect(c),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_picking)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: PrimaryButton(
                        label: widget.mode == NewChatMode.group
                            ? _selected.isEmpty
                                  ? 'Vytvoriť skupinu'
                                  : 'Vytvoriť skupinu (${_selected.length + 1})'
                            : 'Pridať (${_selected.length})',
                        icon: Icons.check_rounded,
                        onPressed: _canSubmit && !_busy ? _submit : null,
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

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });
}
