import 'package:flutter/material.dart';

import 'component_states.dart';
import 'colors.dart';
import 'progress.dart';
import 'spacing.dart';
import 'typography.dart';

/// App-level TinyWins theme configuration.
abstract final class TinyWinsTheme {
  static ThemeData light() {
    const typography = TinyWinsTypography.light;
    const spacing = TwSpacingScheme.comfortable;
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: TinyWinsColors.primaryGreen,
      onPrimary: Colors.white,
      secondary: TinyWinsColors.tealAccent,
      onSecondary: Colors.white,
      error: TinyWinsColors.error,
      onError: Colors.white,
      surface: TinyWinsColors.surface,
      onSurface: TinyWinsColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TinyWinsColors.background,
      textTheme: typography.toTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        typography,
        spacing,
        TwControlStates.light,
        TwProgressTheme.light,
      ],
      cardTheme: const CardThemeData(
        color: TinyWinsColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: TinyWinsColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: TinyWinsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: TinyWinsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide:
              BorderSide(color: TinyWinsColors.primaryGreen, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: Size(0, spacing.controlHeight),
          padding: spacing.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          textStyle: typography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, spacing.controlHeight),
          padding: spacing.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          side: const BorderSide(color: TinyWinsColors.primaryGreen),
          textStyle: typography.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TinyWinsColors.primaryGreen,
        linearTrackColor: TinyWinsColors.surfaceLight,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: TinyWinsColors.border, width: 1.2),
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return TinyWinsColors.primaryGreen;
          }
          return Colors.white;
        }),
      ),
      dividerColor: TinyWinsColors.border,
    );
  }

  static ThemeData dark() {
    const typography = TinyWinsTypography.dark;
    const spacing = TwSpacingScheme.comfortable;
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: TinyWinsColors.primaryGreen,
      onPrimary: Colors.white,
      secondary: TinyWinsColors.tealAccent,
      onSecondary: Colors.white,
      error: TinyWinsColors.error,
      onError: Colors.white,
      surface: Color(0xFF1E2937),
      onSurface: Color(0xFFF8FAFC),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      textTheme: typography.toTextTheme(),
      extensions: const <ThemeExtension<dynamic>>[
        typography,
        spacing,
        TwControlStates.dark,
        TwProgressTheme.dark,
      ],
      cardTheme: const CardThemeData(
        color: Color(0xFF1E2937),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0xFF334155)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1E2937),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide:
              BorderSide(color: TinyWinsColors.primaryGreen, width: 1.4),
        ),
      ),
      dividerColor: const Color(0xFF334155),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TinyWinsColors.primaryGreen,
        linearTrackColor: Color(0xFF334155),
      ),
    );
  }
}
