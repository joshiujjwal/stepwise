import 'dart:ui';

import 'package:flutter/material.dart';

/// Spacing tokens from TinyWins' 8-point grid.
abstract final class TwSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
}

enum TwDensity { comfortable, compact }

/// Density-aware spacing scheme for focus mode.
@immutable
class TwSpacingScheme extends ThemeExtension<TwSpacingScheme> {
  const TwSpacingScheme({
    required this.density,
    required this.screenPadding,
    required this.cardPadding,
    required this.buttonPadding,
    required this.controlHeight,
  });

  final TwDensity density;
  final EdgeInsets screenPadding;
  final EdgeInsets cardPadding;
  final EdgeInsets buttonPadding;
  final double controlHeight;

  static const TwSpacingScheme comfortable = TwSpacingScheme(
    density: TwDensity.comfortable,
    screenPadding: TwSpacing.screenPadding,
    cardPadding: TwSpacing.cardPadding,
    buttonPadding: TwSpacing.buttonPadding,
    controlHeight: 48,
  );

  static const TwSpacingScheme compact = TwSpacingScheme(
    density: TwDensity.compact,
    screenPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    cardPadding: EdgeInsets.all(16),
    buttonPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    controlHeight: 44,
  );

  @override
  TwSpacingScheme copyWith({
    TwDensity? density,
    EdgeInsets? screenPadding,
    EdgeInsets? cardPadding,
    EdgeInsets? buttonPadding,
    double? controlHeight,
  }) {
    return TwSpacingScheme(
      density: density ?? this.density,
      screenPadding: screenPadding ?? this.screenPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      buttonPadding: buttonPadding ?? this.buttonPadding,
      controlHeight: controlHeight ?? this.controlHeight,
    );
  }

  @override
  TwSpacingScheme lerp(ThemeExtension<TwSpacingScheme>? other, double t) {
    if (other is! TwSpacingScheme) return this;
    return TwSpacingScheme(
      density: t < 0.5 ? density : other.density,
      screenPadding: EdgeInsets.lerp(screenPadding, other.screenPadding, t)!,
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
      buttonPadding: EdgeInsets.lerp(buttonPadding, other.buttonPadding, t)!,
      controlHeight:
          lerpDouble(controlHeight, other.controlHeight, t) ?? controlHeight,
    );
  }
}

extension TwSpacingContext on BuildContext {
  TwSpacingScheme get twSpacing {
    return Theme.of(this).extension<TwSpacingScheme>() ??
        TwSpacingScheme.comfortable;
  }
}

class TwGap extends StatelessWidget {
  const TwGap.v(this.value, {super.key}) : width = 0;

  const TwGap.h(this.value, {super.key}) : width = value;

  final double value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: width == 0 ? value : 0);
  }
}
