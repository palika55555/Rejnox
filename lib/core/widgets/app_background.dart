import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Jednotný antracit bez žiary; kontrast vytvárajú karty a koralové akcie.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.bg, child: child);
}
