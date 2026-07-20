import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF18211D);
  static const _paper = Color(0xFFF5F6F3);
  static const _green = Color(0xFF126B52);
  static const _coral = Color(0xFFBA493E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: Brightness.light,
      surface: _paper,
      error: _coral,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6EC6A7),
      brightness: Brightness.dark,
      surface: const Color(0xFF151916),
      error: const Color(0xFFFFB4AB),
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static Color get ink => _ink;
}
