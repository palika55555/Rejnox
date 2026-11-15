import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_colors.dart';
import 'package:rejnox/core/theme/app_theme.dart';

double _contrast(Color first, Color second) {
  final a = first.computeLuminance(), b = second.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  test('hlavné tlačidlo má čitateľný text na koralovej', () {
    final theme = AppTheme.dark(webFonts: false);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(
      _contrast(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(theme.colorScheme.error, AppColors.error);
    expect(theme.progressIndicatorTheme.color, AppColors.accent);
  });

  test('texty a významové farby sú čitateľné na tmavých plochách', () {
    for (final surface in [
      AppColors.bg,
      AppColors.surface,
      AppColors.sheet,
      AppColors.hero,
    ]) {
      for (final foreground in [
        AppColors.text,
        AppColors.ink2,
        AppColors.muted,
        AppColors.accent,
        AppColors.good,
        AppColors.error,
      ]) {
        expect(
          _contrast(foreground, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $surface',
        );
      }
    }
  });
}
