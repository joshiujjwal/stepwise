import 'package:flutter/material.dart';

import 'colors.dart';

/// Typed text tokens used across TinyWins.
@immutable
class TinyWinsTypography extends ThemeExtension<TinyWinsTypography> {
  const TinyWinsTypography({
    required this.displayLarge,
    required this.headline,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.label,
    required this.caption,
  });

  final TextStyle displayLarge;
  final TextStyle headline;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle label;
  final TextStyle caption;

  static const TinyWinsTypography light = TinyWinsTypography(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: TinyWinsColors.textPrimary,
      height: 1.15,
      letterSpacing: -0.24,
    ),
    headline: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: TinyWinsColors.textPrimary,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: TinyWinsColors.textPrimary,
      height: 1.25,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: TinyWinsColors.textPrimary,
      height: 1.28,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: TinyWinsColors.textSecondary,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: TinyWinsColors.textSecondary,
      height: 1.42,
    ),
    label: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: TinyWinsColors.textSecondary,
      height: 1.33,
    ),
    caption: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: TinyWinsColors.textMuted,
      height: 1.36,
    ),
  );

  static const TinyWinsTypography dark = TinyWinsTypography(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: Color(0xFFF8FAFC),
      height: 1.15,
      letterSpacing: -0.24,
    ),
    headline: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: Color(0xFFF8FAFC),
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFFF8FAFC),
      height: 1.25,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFFF8FAFC),
      height: 1.28,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFFCBD5E1),
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFFCBD5E1),
      height: 1.42,
    ),
    label: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Color(0xFFE2E8F0),
      height: 1.33,
    ),
    caption: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: Color(0xFF94A3B8),
      height: 1.36,
    ),
  );

  TextTheme toTextTheme() => TextTheme(
        displayLarge: displayLarge,
        headlineSmall: headline,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: label,
        bodySmall: caption,
      );

  @override
  TinyWinsTypography copyWith({
    TextStyle? displayLarge,
    TextStyle? headline,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return TinyWinsTypography(
      displayLarge: displayLarge ?? this.displayLarge,
      headline: headline ?? this.headline,
      titleLarge: titleLarge ?? this.titleLarge,
      titleMedium: titleMedium ?? this.titleMedium,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  TinyWinsTypography lerp(ThemeExtension<TinyWinsTypography>? other, double t) {
    if (other is! TinyWinsTypography) {
      return this;
    }
    return TinyWinsTypography(
      displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

extension TinyWinsTypographyContext on BuildContext {
  TinyWinsTypography get twText {
    return Theme.of(this).extension<TinyWinsTypography>() ??
        TinyWinsTypography.light;
  }
}
