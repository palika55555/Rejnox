import 'package:flutter/material.dart';

/// Farebná paleta Rejnox: hlboká nočná modrá s fialovou žiarou (podľa loga).
abstract final class AppColors {
  static const bg = Color(0xFF06061A);
  static const surface = Color(0xFF12112D);
  static const surfaceHi = Color(0xFF1E1B45);
  static const border = Color(0x24A99BFF);
  static const grid = Color(0x0AFFFFFF);

  static const text = Color(0xFFF4F3FF);
  static const muted = Color(0xFF8B88B5);

  /// Stav a progres (percentá, PR, aktívna položka).
  static const accent = Color(0xFFA48BFF);

  /// Hlavná akcia: prechod modrá → fialová ako na logu.
  static const blue = Color(0xFF5468FF);
  static const violet = Color(0xFF9B5CFF);

  /// Kalórie a séria dní.
  static const flame = Color(0xFFFF8A3D);

  static const actionGradient = LinearGradient(colors: [blue, violet]);
}

/// Farby olympijských kotúčov – označujú cviky a svalové partie.
enum Plate {
  red(Color(0xFFFF4D6A)),
  blue(Color(0xFF4D8BFF)),
  yellow(Color(0xFFFFC542)),
  green(Color(0xFF2BD98B));

  const Plate(this.color);
  final Color color;
}
