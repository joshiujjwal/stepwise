import 'package:flutter/material.dart';

/// Brand, semantic, and surface colors for TinyWins.
abstract final class TinyWinsColors {
  // Primary palette
  static const Color primaryGreen = Color(0xFF059669);
  static const Color primaryGreenLight = Color(0xFF10B981);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color winOrange = Color(0xFFF59E0B);

  // Neutrals
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);

  // Semantic
  static const Color success = primaryGreenLight;
  static const Color warning = winOrange;
  static const Color error = Color(0xFFEF4444);
}

abstract final class TinyWinsGradients {
  static const LinearGradient hero = LinearGradient(
    colors: <Color>[
      TinyWinsColors.primaryGreen,
      TinyWinsColors.tealAccent,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
