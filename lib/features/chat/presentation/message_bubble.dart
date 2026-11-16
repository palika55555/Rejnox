import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/chat_models.dart';
import 'chat_widgets.dart';
import '../../../core/theme/app_spacing.dart';

/// Čo chce používateľ so správou urobiť (z ponuky po podržaní).
sealed class MessageAction {
  const MessageAction();
}

class ReactAction extends MessageAction {
  const ReactAction(this.emoji);
  final String emoji;
}

class ReplyAction extends MessageAction {
  const ReplyAction();
}

class EditAction extends MessageAction {
  const EditAction();
}

class DeleteAction extends MessageAction {
  const DeleteAction();
}

/// Systémová správa v strede (napr. „Jana pridala Petra“).
class SystemNote extends StatelessWidget {
  const SystemNote(this.message, {super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.sm,
      horizontal: AppSpacing.xxl,
    ),
    child: Text(
      message.body ?? '',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        color: AppColors.muted,
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

/// Bublina správy: meno odosielateľa (v skupine), citácia, text alebo fotka,
/// čas, „upravené“ a reakcie.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.showSender,
    required this.onAction,
    this.seen = false,
    this.canInteract = true,
    this.canDelete = false,
  });

  final ChatMessage message;

  /// Ukázať meno odosielateľa (skupina, prvá z radu správ).
  final bool showSender;

  /// Pod správou „Videné“.
  final bool seen;

  /// Dá sa reagovať a odpovedať (do konverzácie sa dá písať).
  final bool canInteract;

  /// Smiem zmazať aj cudziu správu (správca skupiny).
  final bool canDelete;
  final ValueChanged<MessageAction> onAction;

  Future<void> _openMenu(BuildContext context) async {
    final m = message;
    if (m.pending || m.deleted) return;
    final action = await showModalBottomSheet<MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _MessageMenu(
        message: m,
        canInteract: canInteract,
        canDelete: m.mine || canDelete,
      ),
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = message;
    final mine = m.mine;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final bubbleColor = m.deleted
        ? Colors.transparent
        : mine
        ? AppColors.accent.withValues(alpha: 0.18)
        : AppColors.surfaceHi;
    final borderColor = mine && !m.deleted
        ? AppColors.accent.withValues(alpha: 0.45)
        : AppColors.border;

    final content = <Widget>[
      if (showSender && !mine && m.senderName != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            m.senderName!,
            style: text.bodySmall!.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      if (m.replyTo != null && !m.deleted) _Quote(m.replyTo!),
      if (m.deleted)
        Text(
          'Správa bola odstránená',
          style: text.bodyMedium!.copyWith(
            color: AppColors.muted,
            fontStyle: FontStyle.italic,
          ),
        )
      else if (m.isImage)
        GestureDetector(
          onTap: m.pending
              ? null
              : () => ChatImageViewer.open(context, messageId: m.id),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Pevný rozmer, aby sa zoznam pri načítaní fotky neposúval.
            child: SizedBox(
              width: maxWidth < 240 ? maxWidth - 24 : 240,
              height: 180,
              child: ChatImage(
                messageId: m.pending ? null : m.id,
                bytes: m.localImage,
              ),
            ),
          ),
        )
      else
        Text(
          m.body ?? '',
          style: text.bodyMedium!.copyWith(color: AppColors.text),
        ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        [
          if (m.edited && !m.deleted) 'upravené',
          if (m.pending) 'Odosiela sa…' else clockTime(m.sentAt),
        ].join(' · '),
        textAlign: TextAlign.right,
        style: text.labelMedium!.copyWith(color: AppColors.muted),
      ),
    ];

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              label: m.mine
                  ? 'Tvoja správa'
                  : 'Správa od ${m.senderName ?? ''}',
              hint: 'Podrž pre možnosti',
              child: GestureDetector(
                onLongPress: () => _openMenu(context),
                onSecondaryTap: () => _openMenu(context),
                child: Opacity(
                  opacity: m.pending ? 0.7 : 1,
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppRadius.lg),
                        topRight: const Radius.circular(AppRadius.lg),
                        bottomLeft: Radius.circular(mine ? 16 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 16),
                      ),
                    ),
                    // Šírka podľa najširšieho riadku, čas vpravo dole.
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (m.reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final r in m.reactions)
                      _ReactionChip(
                        r,
                        onTap: canInteract
                            ? () => onAction(ReactAction(r.emoji))
                            : null,
                      ),
                  ],
                ),
              ),
            if (seen)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xxs,
                  right: AppSpacing.xs,
                ),
                child: Text(
                  'Videné',
                  style: text.labelMedium!.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote(this.reply);

  final ReplyPreview reply;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.35),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply.senderName != null)
            Text(
              reply.senderName!,
              style: text.labelMedium!.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          Text(
            reply.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip(this.reaction, {this.onTap});

  final Reaction reaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: reaction.mine
        ? AppColors.accent.withValues(alpha: 0.2)
        : AppColors.surfaceHi,
    shape: StadiumBorder(
      side: BorderSide(
        color: reaction.mine ? AppColors.accent : AppColors.border,
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          reaction.count > 1
              ? '${reaction.emoji} ${reaction.count}'
              : reaction.emoji,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ),
  );
}

class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.message,
    required this.canInteract,
    required this.canDelete,
  });

  final ChatMessage message;
  final bool canInteract;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.reactions.where((r) => r.mine).firstOrNull?.emoji;
    void pick(MessageAction a) => Navigator.of(context).pop(a);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canInteract)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  for (final e in chatReactions)
                    IconButton(
                      tooltip: 'Reagovať $e',
                      isSelected: e == mine,
                      style: IconButton.styleFrom(
                        backgroundColor: e == mine
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : null,
                      ),
                      onPressed: () => pick(ReactAction(e)),
                      icon: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                ],
              ),
            ),
          if (canInteract)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Odpovedať'),
              onTap: () => pick(const ReplyAction()),
            ),
          if (m.kind == MessageKind.text && m.body != null)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Kopírovať text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.body!));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text je skopírovaný.')),
                );
              },
            ),
          if (m.mine && m.kind == MessageKind.text && canInteract)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Upraviť'),
              onTap: () => pick(const EditAction()),
            ),
          if (canDelete)
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                m.mine ? 'Zmazať' : 'Zmazať (správca)',
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () => pick(const DeleteAction()),
            ),
        ],
      ),
    );
  }
}
