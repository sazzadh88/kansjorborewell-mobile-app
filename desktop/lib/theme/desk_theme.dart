import 'package:flutter/material.dart';

abstract final class DeskColors {
  // Neutral base palette
  static const ink = Color(0xFF1A1D21);
  static const inkSoft = Color(0xFF3A3F47);
  static const canvas = Color(0xFFF4F5F7);
  static const canvasDark = Color(0xFF101216);
  static const panel = Color(0xFFFFFFFF);
  static const panelDark = Color(0xFF191C21);
  static const border = Color(0xFFE1E4E9);
  static const borderDark = Color(0xFF2C3037);
  static const muted = Color(0xFF6B7280);

  // Reserved for primary actions + status only
  static const primary = Color(0xFF2563EB);
  static const primaryTint = Color(0xFFE8EEFD);

  // Status colors
  static const low = Color(0xFFB45309); // amber
  static const dispatched = Color(0xFF2563EB); // blue
  static const settled = Color(0xFF059669); // green
  static const danger = Color(0xFFDC2626);
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class DeskTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: DeskColors.primary,
      onPrimary: Colors.white,
      secondary: DeskColors.primary,
      onSecondary: Colors.white,
      error: DeskColors.danger,
      onError: Colors.white,
      surface: isDark ? DeskColors.panelDark : DeskColors.panel,
      onSurface: isDark ? Colors.white : DeskColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Roboto', 'Inter', 'system-ui'],
      scaffoldBackgroundColor: isDark ? DeskColors.canvasDark : DeskColors.canvas,
      visualDensity: VisualDensity.compact,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? DeskColors.borderDark : DeskColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 14, height: 1.4),
        bodyMedium: TextStyle(fontSize: 12, height: 1.4),
        bodySmall: TextStyle(fontSize: 12),
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? DeskColors.panelDark : DeskColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? DeskColors.borderDark : DeskColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: DeskColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: DeskColors.primary,
          side: const BorderSide(color: DeskColors.primary),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? DeskColors.canvasDark : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? DeskColors.borderDark : DeskColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? DeskColors.borderDark : DeskColors.border),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          isDark ? const Color(0xFF1F2329) : const Color(0xFFF0F1F4),
        ),
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : DeskColors.inkSoft,
        ),
        dataTextStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : DeskColors.ink,
        ),
      ),
    );

    return base;
  }
}
