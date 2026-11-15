import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// Nadpisy a čísla: zúžený ťažký rez ako razené číslo na kotúči.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.text,
    bool webFonts = true,
  }) {
    final s = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.0,
      letterSpacing: size * 0.01,
    );
    return webFonts ? GoogleFonts.bigShoulders(textStyle: s) : s;
  }

  /// [webFonts] = false vypne sťahovanie fontov (testy, offline).
  static ThemeData dark({bool webFonts = true}) {
    TextStyle head(double size, {FontWeight weight = FontWeight.w800}) =>
        display(size, weight: weight, webFonts: webFonts);

    TextStyle body(
      double size, {
      FontWeight weight = FontWeight.w400,
      Color color = AppColors.text,
      double spacing = 0,
    }) {
      final s = TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.35,
      );
      return webFonts ? GoogleFonts.onest(textStyle: s) : s;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Jednotný podklad kreslí AppBackground (resp. AuthBackground).
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.accent,
        onSecondary: AppColors.bg,
        tertiary: AppColors.good,
        onTertiary: AppColors.bg,
        surface: AppColors.sheet,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.ink2,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        error: AppColors.error,
        onError: AppColors.bg,
        surfaceTint: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.well,
        circularTrackColor: AppColors.well,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentSoft,
        selectionHandleColor: AppColors.accent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkRipple.splashFactory,
      highlightColor: AppColors.well,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.sheet,
        contentTextStyle: body(
          14.5,
          weight: FontWeight.w600,
          color: AppColors.onHero,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        titleTextStyle: head(24),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.buttonSurface,
          foregroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.well,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppColors.buttonBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: body(16, weight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: body(16, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: body(14, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: body(14, color: AppColors.muted),
        hintStyle: body(15, color: AppColors.muted),
        helperStyle: body(12, color: AppColors.muted),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: head(31),
        headlineMedium: head(24),
        titleLarge: head(22),
        titleMedium: body(16.5, weight: FontWeight.w700),
        bodyLarge: body(15, weight: FontWeight.w600),
        bodyMedium: body(14),
        bodySmall: body(12.5, color: AppColors.ink2),
        labelLarge: body(16, weight: FontWeight.w700),
        labelSmall: body(
          11.5,
          weight: FontWeight.w600,
          color: AppColors.muted,
          spacing: 1.0,
        ),
      ),
    );
  }
}
