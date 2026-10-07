import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: Tokens.beacon,
      onPrimary: Tokens.shaft,
      secondary: Tokens.beacon,
      onSecondary: Tokens.shaft,
      surface: Tokens.seam,
      onSurface: Tokens.chalk,
      error: Tokens.flare,
      onError: Tokens.chalk,
      outline: Tokens.rule,
      outlineVariant: Tokens.rule,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Tokens.shaft,
      canvasColor: Tokens.shaft,
      dividerColor: Tokens.rule,
      dividerTheme: const DividerThemeData(
        color: Tokens.rule,
        thickness: Tokens.hairline,
        space: Tokens.hairline,
      ),
      textTheme: TextTheme(
        displaySmall: AppType.display,
        titleLarge: AppType.heading,
        titleMedium: AppType.bodyStrong,
        bodyMedium: AppType.body,
        bodySmall: AppType.bodyMuted,
        labelSmall: AppType.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Tokens.shaft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.display,
        iconTheme: const IconThemeData(color: Tokens.slate),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Tokens.seam,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Tokens.beacon.withValues(alpha: 0.16),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.label.copyWith(
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? Tokens.chalk
                : Tokens.slate,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? Tokens.beacon
                : Tokens.slate,
          ),
        ),
      ),
      // Keyboard focus must always be visible — it is part of the quality
      // floor, not an accessibility extra.
      focusColor: Tokens.beacon,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
