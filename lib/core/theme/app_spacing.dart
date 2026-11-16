/// Medzery na 4-bodovej mriežke. Iné hodnoty v paddingu a medzerách
/// nepoužívaj; ak niečo nesedí, chýba token, nie číslo.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  static const scale = [xxs, xs, sm, md, lg, xl, xxl, xxxl, huge];
}

/// Zaoblenia rohov od drobných štítkov po spodné sheety.
abstract final class AppRadius {
  /// Štítky, prúžky, malé indikátory.
  static const double xs = 4;

  /// Čipy, malé dlaždice.
  static const double sm = 8;

  /// Vnorené plochy v kartách.
  static const double md = 12;

  /// Tlačidlá, inputy, snackbary.
  static const double lg = 16;

  /// Karty.
  static const double xl = 20;

  /// Dialógy.
  static const double xxl = 24;

  /// Spodné sheety a hero plochy.
  static const double sheet = 28;

  static const scale = [xs, sm, md, lg, xl, xxl, sheet];
}
