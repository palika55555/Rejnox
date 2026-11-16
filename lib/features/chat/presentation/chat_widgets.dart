import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_api.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Čas správy: dnes len hodiny, inak deň a mesiac.
String shortTime(DateTime time, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final sameDay =
      time.year == today.year &&
      time.month == today.month &&
      time.day == today.day;
  return sameDay
      ? '${time.hour}:${_two(time.minute)}'
      : '${time.day}. ${time.month}.';
}

/// Hodiny a minúty (v bubline správy).
String clockTime(DateTime time) => '${time.hour}:${_two(time.minute)}';

/// Nadpis dňa v konverzácii: Dnes, Včera, alebo dátum.
String dayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Dnes';
  if (diff == 1) return 'Včera';
  return day.year == today.year
      ? '${day.day}. ${day.month}.'
      : '${day.day}. ${day.month}. ${day.year}';
}

/// Chyba pre používateľa (zo servera alebo všeobecná).
String chatErrorText(Object error, [String fallback = 'Niečo sa pokazilo.']) =>
    error is ApiError ? error.message : fallback;

void showChatError(
  BuildContext context,
  Object error, [
  String fallback = 'Niečo sa pokazilo.',
]) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(chatErrorText(error, fallback))));
}

/// Kruh s počiatočným písmenom mena, pri skupine ikona ľudí.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar(this.name, {super.key, this.size = 42, this.group = false});

  final String name;
  final double size;
  final bool group;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: group
            ? AppColors.accent.withValues(alpha: 0.16)
            : AppColors.surfaceHi,
        border: Border.all(
          color: group
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: group
          ? Icon(
              Icons.groups_rounded,
              size: size * 0.5,
              color: AppColors.accent,
            )
          : Text(
              trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: AppColors.accent,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}

/// Počet neprečítaných (odznak). Stlmená konverzácia má sivý.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? AppColors.muted : AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.bg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Fotka zo správy. Zo servera sa načíta s prihlasovacím tokenom,
/// počas odosielania sa ukáže z pamäte.
class ChatImage extends ConsumerWidget {
  const ChatImage({
    super.key,
    this.messageId,
    this.bytes,
    this.fit = BoxFit.cover,
  });

  final String? messageId;
  final List<int>? bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = bytes;
    if (local != null) {
      return Image.memory(Uint8List.fromList(local), fit: fit);
    }
    final token = switch (ref.watch(authControllerProvider)) {
      SignedIn(:final token) => token,
      _ => null,
    };
    final id = messageId;
    if (id == null || token == null) return const _ImagePlaceholder();
    return Image.network(
      chatImageUrl(id),
      fit: fit,
      headers: {'authorization': 'Bearer $token'},
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ImagePlaceholder(loading: true),
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surfaceHi,
    alignment: Alignment.center,
    child: loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.broken_image_outlined, color: AppColors.muted),
  );
}

/// Fotka na celú obrazovku s priblížením.
class ChatImageViewer extends StatelessWidget {
  const ChatImageViewer({super.key, this.messageId, this.bytes});

  final String? messageId;
  final List<int>? bytes;

  static Future<void> open(
    BuildContext context, {
    String? messageId,
    List<int>? bytes,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ChatImageViewer(messageId: messageId, bytes: bytes),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Zavrieť',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: ChatImage(
          messageId: messageId,
          bytes: bytes,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

/// Prázdny stav alebo chyba uprostred obrazovky (dá sa potiahnuť nadol).
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 28),
      children: [
        Icon(icon, size: 40, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(title, style: text.titleMedium, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 12),
          Center(child: action),
        ],
      ],
    );
  }
}

/// Potvrdenie pred nevratnou akciou. Vráti true pri potvrdení.
Future<bool> confirmChatAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;
