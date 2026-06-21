import 'package:flutter/material.dart';

import 'colors.dart';

/// Standardized control states used by interactive components.
@immutable
class TwControlStates extends ThemeExtension<TwControlStates> {
  const TwControlStates({
    required this.defaultBg,
    required this.defaultFg,
    required this.hoverBg,
    required this.pressedBg,
    required this.focusBorder,
    required this.disabledBg,
    required this.disabledFg,
    required this.loadingBg,
    required this.errorBg,
    required this.successBg,
  });

  final Color defaultBg;
  final Color defaultFg;
  final Color hoverBg;
  final Color pressedBg;
  final Color focusBorder;
  final Color disabledBg;
  final Color disabledFg;
  final Color loadingBg;
  final Color errorBg;
  final Color successBg;

  static const TwControlStates light = TwControlStates(
    defaultBg: TinyWinsColors.primaryGreen,
    defaultFg: Colors.white,
    hoverBg: TinyWinsColors.primaryGreenLight,
    pressedBg: Color(0xFF047857),
    focusBorder: TinyWinsColors.tealAccent,
    disabledBg: TinyWinsColors.surfaceLight,
    disabledFg: TinyWinsColors.textMuted,
    loadingBg: TinyWinsColors.tealAccent,
    errorBg: TinyWinsColors.error,
    successBg: TinyWinsColors.success,
  );

  static const TwControlStates dark = TwControlStates(
    defaultBg: TinyWinsColors.primaryGreen,
    defaultFg: Colors.white,
    hoverBg: TinyWinsColors.primaryGreenLight,
    pressedBg: Color(0xFF047857),
    focusBorder: TinyWinsColors.tealAccent,
    disabledBg: Color(0xFF334155),
    disabledFg: Color(0xFF64748B),
    loadingBg: TinyWinsColors.tealAccent,
    errorBg: TinyWinsColors.error,
    successBg: TinyWinsColors.success,
  );

  @override
  TwControlStates copyWith({
    Color? defaultBg,
    Color? defaultFg,
    Color? hoverBg,
    Color? pressedBg,
    Color? focusBorder,
    Color? disabledBg,
    Color? disabledFg,
    Color? loadingBg,
    Color? errorBg,
    Color? successBg,
  }) {
    return TwControlStates(
      defaultBg: defaultBg ?? this.defaultBg,
      defaultFg: defaultFg ?? this.defaultFg,
      hoverBg: hoverBg ?? this.hoverBg,
      pressedBg: pressedBg ?? this.pressedBg,
      focusBorder: focusBorder ?? this.focusBorder,
      disabledBg: disabledBg ?? this.disabledBg,
      disabledFg: disabledFg ?? this.disabledFg,
      loadingBg: loadingBg ?? this.loadingBg,
      errorBg: errorBg ?? this.errorBg,
      successBg: successBg ?? this.successBg,
    );
  }

  @override
  TwControlStates lerp(ThemeExtension<TwControlStates>? other, double t) {
    if (other is! TwControlStates) return this;
    return TwControlStates(
      defaultBg: Color.lerp(defaultBg, other.defaultBg, t)!,
      defaultFg: Color.lerp(defaultFg, other.defaultFg, t)!,
      hoverBg: Color.lerp(hoverBg, other.hoverBg, t)!,
      pressedBg: Color.lerp(pressedBg, other.pressedBg, t)!,
      focusBorder: Color.lerp(focusBorder, other.focusBorder, t)!,
      disabledBg: Color.lerp(disabledBg, other.disabledBg, t)!,
      disabledFg: Color.lerp(disabledFg, other.disabledFg, t)!,
      loadingBg: Color.lerp(loadingBg, other.loadingBg, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
    );
  }
}

extension TwControlStatesContext on BuildContext {
  TwControlStates get twControlStates {
    return Theme.of(this).extension<TwControlStates>() ?? TwControlStates.light;
  }
}
