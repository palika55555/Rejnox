import 'package:flutter/material.dart';

/// Rejnox: koralová značka, antracitové plochy a čitateľné neutrálne texty.
/// Zelená potvrdzuje úspech; farby kotúčov a zón majú vlastný význam.
abstract final class AppColors {
  static const bg = Color(0xFF14171B);
  static const surface = Color(0xFF1A1E23);
  static const well = Color(0xFF242A31);
  static const surfaceHi = Color(0xFF2A3038);
  static const sheet = Color(0xFF1C2127);
  static const border = Color(0xFF343B44);
  static const grid = Color(0xFF272D34);

  static const text = Color(0xFFF4F5F7);
  static const ink2 = Color(0xFFB5BFCC);
  static const muted = Color(0xFF939EAD);

  /// Tmavý text na koralovej výplni má vyšší kontrast než biely.
  static const primary = Color(0xFFFF6247);
  static const onAccent = Color(0xFF14171B);
  static const accent = primary;
  static const accentDeep = Color(0xFFE34C35);
  static const accentSoft = Color(0x24FF6247);

  static const hero = Color(0xFF211F22);
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF302326), Color(0xFF202227), surface],
  );
  static const onHero = text;
  static const onHero2 = ink2;
  static const heroLine = Color(0xFF51403D);

  static const good = Color(0xFF3DDA8D);
  static const goodSoft = Color(0x203DDA8D);
  static const warn = Color(0xFFF0B84C);
  static const warnSoft = Color(0x29F0B84C);
  static const info = Color(0xFFB5BFCC);
  static const infoSoft = Color(0x20B5BFCC);
  static const steel = Color(0xFF9AA5B2);
  static const flame = primary;
  static const error = Color(0xFFFF6B7F);

  static const actionGradient = LinearGradient(colors: [primary, primary]);
  static const buttonSurface = Color(0xFF2B2323);
  static const buttonBorder = Color(0xFF664039);
}

/// Farby záťažových kotúčov, nezávislé od farebnosti značky.
enum Plate {
  red(Color(0xFFFF4D6A)),
  blue(Color(0xFF4D8BFF)),
  yellow(Color(0xFFFFC542)),
  green(Color(0xFF2BD98B));

  const Plate(this.color);
  final Color color;
}
