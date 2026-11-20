import 'dart:ui';

import 'package:flutter/material.dart';

/// Centralized theme and reusable widgets for NFQ Studio.
class StudioTheme {
  StudioTheme._();

  static ThemeData _theme = dark();
  static ColorScheme _colorScheme = _theme.colorScheme;
  static bool _isDark = true;

  static ThemeData get theme => _theme;
  static ColorScheme get colorScheme => _colorScheme;
  static bool get isDark => _isDark;

  static bool? _lastIsDark;

  /// Updates the global static theme state.
  /// Should be called at the root of the app (e.g. in MaterialApp.builder).
  static void update(final BuildContext context) {
    _theme = Theme.of(context);
    _colorScheme = _theme.colorScheme;
    final isDarkNew = _theme.brightness == Brightness.dark;
    final changed = _lastIsDark != null && _lastIsDark != isDarkNew;
    _isDark = isDarkNew;
    _lastIsDark = isDarkNew;

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((final _) {
        rebuildDescendantChildren(context);
      });
    }
  }

  /// Force-rebuilds all descendants of the given context.
  ///
  /// Used to ensure that leaf widgets using static theme access refresh
  /// when the theme changes, bypassing const optimizations.
  static void rebuildDescendantChildren(final BuildContext context) {
    void rebuild(final Element el) {
      el
        ..markNeedsBuild()
        ..visitChildren(rebuild);
    }

    if (context is Element) {
      context.visitChildren(rebuild);
    }
  }

  static const primaryColor = Color(0xFF0F172A);
  static const surfaceColor = Color(0xFF1E293B);
  static const accentColor = Color(0xFF38BDF8);

  static const lightPrimaryColor = Color(0xFFF8FAFC);
  static const lightSurfaceColor = Color(0xFFFFFFFF);
  // Sky-700: High-contrast accessible primary blue
  static const lightAccentColor = Color(0xFF0369A1);

  static ThemeData light() => ThemeData.light().copyWith(
        scaffoldBackgroundColor: lightPrimaryColor,
        colorScheme: const ColorScheme.light(
          primary: lightAccentColor,
          onPrimary: Colors.white,
          secondary: Color(0xFF0EA5E9), // Sky-500
          onSecondary: Colors.white,
          surface: lightSurfaceColor,
          onSurface: Color(0xFF0F172A), // Slate-900
          primaryContainer: Color(0xFFE0F2FE), // Sky-100
          onPrimaryContainer: Color(0xFF0369A1), // Sky-700
          secondaryContainer: Color(0xFFF1F5F9), // Slate-100
          onSecondaryContainer: Color(0xFF0F172A),
          error: Color(0xFFDC2626), // Red-600
          onError: Colors.white,
          outline: Color(0xFFCBD5E1), // Slate-300
          outlineVariant: Color(0xFFE2E8F0), // Slate-200
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: Color(0xFF0F172A), // Slate-900
          ),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      );

  static ThemeData dark() => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          surface: surfaceColor,
          onSurface: Colors.white,
          primaryContainer: Color(0xFF0F172A),
          onPrimaryContainer: Color(0xFF38BDF8),
          secondaryContainer: Color(0xFF1E293B),
          onSecondaryContainer: Colors.white,
          surfaceContainerHigh: Color(0xFF1E293B),
          surfaceContainerHighest: Color(0xFF283548),
          outline: Color(0x66475569),
          outlineVariant: Color(0x40334155),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      );
}

/// A frosted-glass card widget for premium UI elements.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(final BuildContext context) {
    final isDark = StudioTheme.isDark;
    final colorScheme = StudioTheme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
