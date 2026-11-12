import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// [webFonts] = false vypne sťahovanie fontov (testy, offline).
  static ThemeData dark({bool webFonts = true}) {
    TextStyle head(double size) {
      final s = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
        height: 1.05,
        letterSpacing: -0.5,
      );
      return webFonts ? GoogleFonts.montserrat(textStyle: s) : s;
    }

    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w500,
      Color color = AppColors.text,
      double spacing = 0,
    }) {
      final s = TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );
      return webFonts ? GoogleFonts.inter(textStyle: s) : s;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Pozadie kreslí AppBackground (žiara), Scaffold je priehľadný.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.text,
      ),
      splashFactory: InkSparkle.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg.withValues(alpha: 0.6),
        labelStyle: body(14, color: AppColors.muted),
        helperStyle: body(11, color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: head(30),
        headlineMedium: head(26),
        titleLarge: head(18),
        titleMedium: body(15, weight: FontWeight.w700),
        bodyLarge: body(14, weight: FontWeight.w600),
        bodyMedium: body(13),
        bodySmall: body(11, color: AppColors.muted),
        labelLarge: body(15, weight: FontWeight.w700),
        labelSmall: body(
          10,
          weight: FontWeight.w700,
          color: AppColors.muted,
          spacing: 1.2,
        ),
      ),
    );
  }
}
