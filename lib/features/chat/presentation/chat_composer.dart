import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/chat_models.dart';
import '../../../core/theme/app_spacing.dart';

/// Pole na písanie: odpoveď / úprava nad ním, fotka a odoslanie.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.onTyping,
    this.onPickImage,
    this.replyTo,
    this.editing,
    this.onCancel,
  });

  /// Vráti false, ak sa odoslanie nepodarilo (text ostane v poli).
  final Future<bool> Function(String text) onSend;
  final VoidCallback onTyping;
  final VoidCallback? onPickImage;
  final ChatMessage? replyTo;
  final ChatMessage? editing;

  /// Zruší odpoveď alebo úpravu.
  final VoidCallback? onCancel;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _canSend = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatComposer old) {
    super.didUpdateWidget(old);
    final editing = widget.editing;
    if (editing != null && editing.id != old.editing?.id) {
      _controller.text = editing.body ?? '';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      _focus.requestFocus();
    } else if (editing == null && old.editing != null) {
      _controller.clear();
    }
    if (widget.replyTo != null && widget.replyTo?.id != old.replyTo?.id) {
      _focus.requestFocus();
    }
  }

  void _changed() {
    final can = _controller.text.trim().isNotEmpty;
    if (can != _canSend) setState(() => _canSend = can);
    if (can && widget.editing == null) widget.onTyping();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    _sending = true;
    _controller.clear();
    final ok = await widget.onSend(body);
    _sending = false;
    // Text sa pri chybe vráti do poľa, nech sa nestratí.
    if (!ok && mounted && _controller.text.isEmpty) _controller.text = body;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final editing = widget.editing;
    final reply = widget.replyTo;
    final banner = editing != null
        ? ('Upravuješ správu', editing.preview, Icons.edit_outlined)
        : reply != null
        ? (
            'Odpoveď pre ${reply.mine ? 'seba' : reply.senderName ?? ''}',
            reply.preview,
            Icons.reply_rounded,
          )
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (banner != null)
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: const Border(
                left: BorderSide(color: AppColors.accent, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(banner.$3, size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.$1,
                        style: text.bodySmall!.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        banner.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zrušiť',
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Poslať fotku',
                onPressed: editing == null ? widget.onPickImage : null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
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
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                tooltip: editing == null ? 'Odoslať' : 'Uložiť úpravu',
                onPressed: _canSend ? _send : null,
                icon: Icon(
                  editing == null ? Icons.send_rounded : Icons.check_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
