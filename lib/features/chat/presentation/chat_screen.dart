import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/chat_providers.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';

/// Jedna konverzácia tréner–klient. [linkId] je ID ich prepojenia.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.linkId, this.name});

  final String linkId;

  /// Meno druhej strany, ak ho volajúci pozná (inak sa dohľadá v zozname).
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider(linkId));
    final thread = ref
        .watch(chatThreadsProvider)
        .value
        ?.where((t) => t.linkId == linkId)
        .firstOrNull;
    final title = name ?? thread?.name ?? 'Správy';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title,
                    subtitle: thread == null
                        ? null
                        : thread.withTrainer
                        ? 'Tvoj tréner'
                        : 'Tvoj klient',
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/chat'),
                  ),
                  Expanded(
                    child: messages.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e is ApiError ? e.message : 'Niečo sa pokazilo.',
                            ),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(chatProvider(linkId)),
                              child: const Text('Skúsiť znova'),
                            ),
                          ],
                        ),
                      ),
                      data: (list) => _MessageList(list),
                    ),
                  ),
                  if (thread != null && !thread.canSend)
                    const _ClosedNote()
                  else
                    _Composer(linkId: linkId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList(this.messages);

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Zatiaľ žiadne správy. Napíš prvú.',
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Obrátený zoznam: najnovšie dole a pri novej správe ostane dole.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: messages.length,
      itemBuilder: (_, i) {
        final index = messages.length - 1 - i;
        final m = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final newDay =
            previous == null ||
            previous.sentAt.day != m.sentAt.day ||
            previous.sentAt.month != m.sentAt.month;
        return Column(
          children: [
            if (newDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '${m.sentAt.day}. ${m.sentAt.month}. ${m.sentAt.year}',
                  style: text.bodySmall!.copyWith(color: AppColors.muted),
                ),
              ),
            _Bubble(m),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.surfaceHi,
            border: Border.all(
              color: mine
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SelectableText(
                message.body,
                style: text.bodyMedium!.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 2),
              Text(
                message.pending
                    ? 'Odosiela sa…'
                    : shortTime(message.sentAt, now: message.sentAt),
                style: text.bodySmall!.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: Text(
      'Spolupráca skončila. Správy si môžeš prečítať, písať už nejde.',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall!.copyWith(color: AppColors.muted),
    ),
  );
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({required this.linkId});

  final String linkId;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    _controller.clear();
    try {
      await ref.read(chatProvider(widget.linkId).notifier).send(body);
    } on Object catch (e) {
      if (!mounted) return;
      // Text sa vráti do poľa, nech sa nestratí.
      if (_controller.text.isEmpty) _controller.text = body;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiError ? e.message : 'Správu sa nepodarilo odoslať.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Napíš správu…',
                counterText: '',
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Odoslať',
            onPressed: _canSend ? _send : null,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
