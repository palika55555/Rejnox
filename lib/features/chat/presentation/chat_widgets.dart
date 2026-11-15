import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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

/// Kruh s počiatočným písmenom mena.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar(this.name, {super.key, this.size = 42});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHi,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.titleMedium!.copyWith(color: AppColors.accent),
      ),
    );
  }
}

/// Počet neprečítaných (odznak).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
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
