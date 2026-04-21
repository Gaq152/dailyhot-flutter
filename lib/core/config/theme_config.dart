import 'package:flutter/material.dart';

class ThemeConfig {
  static const _seed = Color(0xFFE8401C);

  static ThemeData get lightTheme {
    final cs = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: cs.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      scaffoldBackgroundColor: cs.surfaceContainerLowest,
    );
  }

  static ThemeData get darkTheme {
    final cs = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
