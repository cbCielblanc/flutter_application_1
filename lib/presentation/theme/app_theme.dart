import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const primarySeed = Color(0xFF4C6EF5);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
    );

    final colorScheme = baseScheme.copyWith(
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFE8ECF7),
      secondary: const Color(0xFF38BDF8),
      secondaryContainer: const Color(0xFFD5F4FF),
      tertiary: const Color(0xFF10B981),
      tertiaryContainer: const Color(0xFFD7F9ED),
    );

    final appliedTextTheme = ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF1B1F3B),
          displayColor: const Color(0xFF1B1F3B),
        );

    final textTheme = appliedTextTheme.copyWith(
      headlineSmall: (appliedTextTheme.headlineSmall ??
              const TextStyle(fontSize: 24, fontWeight: FontWeight.w600))
          .copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: (appliedTextTheme.titleMedium ??
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))
          .copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      bodyMedium: (appliedTextTheme.bodyMedium ??
              const TextStyle(fontSize: 14, height: 1.4))
          .copyWith(height: 1.45),
      labelLarge: (appliedTextTheme.labelLarge ?? const TextStyle(fontSize: 14))
          .copyWith(fontWeight: FontWeight.w600),
    );

    final outlineColor = colorScheme.outline.withOpacity(0.3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1B1F3B),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: (textTheme.titleLarge ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))
            .copyWith(color: const Color(0xFF1B1F3B)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: outlineColor),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: (textTheme.bodyMedium ??
                const TextStyle(fontSize: 14, color: Colors.black54))
            .copyWith(color: const Color(0xFF1B1F3B).withOpacity(0.45)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: (textTheme.labelLarge ?? const TextStyle(fontSize: 14))
            .copyWith(color: const Color(0xFF1B1F3B)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(12),
        thickness: WidgetStateProperty.all(6),
        thumbVisibility: WidgetStateProperty.all(true),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) {
            final base = colorScheme.primary.withOpacity(0.38);
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withOpacity(0.55);
            }
            return base;
          },
        ),
        trackColor: WidgetStateProperty.all(
          colorScheme.surfaceContainerHighest.withOpacity(0.4),
        ),
      ),
    );
  }
}
