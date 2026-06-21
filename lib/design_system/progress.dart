import 'package:flutter/material.dart';

import 'colors.dart';

/// Semantic progress colors and milestone cues.
@immutable
class TwProgressTheme extends ThemeExtension<TwProgressTheme> {
  const TwProgressTheme({
    required this.track,
    required this.fill,
    required this.milestone25,
    required this.milestone50,
    required this.milestone75,
    required this.milestone100,
  });

  final Color track;
  final Color fill;
  final Color milestone25;
  final Color milestone50;
  final Color milestone75;
  final Color milestone100;

  static const TwProgressTheme light = TwProgressTheme(
    track: TinyWinsColors.surfaceLight,
    fill: TinyWinsColors.primaryGreen,
    milestone25: TinyWinsColors.tealAccent,
    milestone50: TinyWinsColors.primaryGreenLight,
    milestone75: TinyWinsColors.primaryGreen,
    milestone100: TinyWinsColors.winOrange,
  );

  static const TwProgressTheme dark = TwProgressTheme(
    track: Color(0xFF334155),
    fill: TinyWinsColors.primaryGreen,
    milestone25: TinyWinsColors.tealAccent,
    milestone50: TinyWinsColors.primaryGreenLight,
    milestone75: TinyWinsColors.primaryGreen,
    milestone100: TinyWinsColors.winOrange,
  );

  Color milestoneFor(double progress) {
    if (progress >= 1) return milestone100;
    if (progress >= 0.75) return milestone75;
    if (progress >= 0.5) return milestone50;
    return milestone25;
  }

  @override
  TwProgressTheme copyWith({
    Color? track,
    Color? fill,
    Color? milestone25,
    Color? milestone50,
    Color? milestone75,
    Color? milestone100,
  }) {
    return TwProgressTheme(
      track: track ?? this.track,
      fill: fill ?? this.fill,
      milestone25: milestone25 ?? this.milestone25,
      milestone50: milestone50 ?? this.milestone50,
      milestone75: milestone75 ?? this.milestone75,
      milestone100: milestone100 ?? this.milestone100,
    );
  }

  @override
  TwProgressTheme lerp(ThemeExtension<TwProgressTheme>? other, double t) {
    if (other is! TwProgressTheme) return this;
    return TwProgressTheme(
      track: Color.lerp(track, other.track, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      milestone25: Color.lerp(milestone25, other.milestone25, t)!,
      milestone50: Color.lerp(milestone50, other.milestone50, t)!,
      milestone75: Color.lerp(milestone75, other.milestone75, t)!,
      milestone100: Color.lerp(milestone100, other.milestone100, t)!,
    );
  }
}

extension TwProgressThemeContext on BuildContext {
  TwProgressTheme get twProgressTheme {
    return Theme.of(this).extension<TwProgressTheme>() ?? TwProgressTheme.light;
  }
}
