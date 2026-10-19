import 'package:flutter/material.dart';

/// Mosaic Pop design tokens: comic-print colour on a cool paper ground.
abstract final class Pop {
  static const ink = Color(0xFF1B1035);
  static const paper = Color(0xFFF4FBFF);
  static const pink = Color(0xFFFF3D8B);
  static const cyan = Color(0xFF19C3FF);
  static const lemon = Color(0xFFFFD93B);
  static const violet = Color(0xFF7A3CFF);
  static const muted = Color(0xFF4A3D6B);
  static const highlight = Color(0xFFFFF4C2);

  /// Glaze colours cycle through the mosaic.
  static const glazes = [lemon, cyan, pink, violet];
  static Color glazeFor(int surah) => glazes[surah % glazes.length];

  /// Card glazes in the order neighbours take them, so two cards next to
  /// each other never share a colour (canvas row G).
  static const cardGlazes = [cyan, pink, lemon, violet];
  static Color cardGlaze(int i) => cardGlazes[i % cardGlazes.length];

  /// Halftone dot colour that reads on each glaze.
  static Color dotsOn(Color glaze) => switch (glaze) {
        pink => const Color(0x381B1035),
        cyan => const Color(0x8CFFFFFF),
        lemon => const Color(0x73FF3D8B),
        violet => const Color(0x4DFFFFFF),
        _ => const Color(0x00000000),
      };

  /// Text colour on a glaze: white on violet, ink on the rest.
  static Color onGlaze(Color glaze) => glaze == violet ? const Color(0xFFFFFFFF) : ink;

  static const display = 'Bungee';
  static const body = 'Baloo 2';
  static const quran = 'Scheherazade New';
}

ThemeData popTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: Pop.body,
    scaffoldBackgroundColor: Pop.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Pop.violet,
      primary: Pop.ink,
      surface: Pop.paper,
      onSurface: Pop.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Pop.ink, displayColor: Pop.ink),
    appBarTheme: const AppBarTheme(backgroundColor: Pop.paper, foregroundColor: Pop.ink, elevation: 0),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Pop.ink,
      contentTextStyle: TextStyle(fontFamily: Pop.body, fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}
