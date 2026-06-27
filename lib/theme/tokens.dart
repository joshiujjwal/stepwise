import 'package:flutter/material.dart';

import '../models/models.dart';

/// Spacing scale (logical pixels). One source of truth for gaps and padding.
@immutable
class AppSpacing {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  static AppSpacing lerp(AppSpacing a, AppSpacing b, double t) => AppSpacing(
        xs: _lerp(a.xs, b.xs, t),
        sm: _lerp(a.sm, b.sm, t),
        md: _lerp(a.md, b.md, t),
        lg: _lerp(a.lg, b.lg, t),
        xl: _lerp(a.xl, b.xl, t),
        xxl: _lerp(a.xxl, b.xxl, t),
      );
}

/// Corner radii. Use [pill] for fully rounded chips/badges.
@immutable
class AppRadius {
  const AppRadius({
    this.sm = 10,
    this.md = 14,
    this.lg = 18,
    this.pill = 999,
  });

  final double sm;
  final double md;
  final double lg;
  final double pill;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get pillAll => BorderRadius.circular(pill);

  static AppRadius lerp(AppRadius a, AppRadius b, double t) => AppRadius(
        sm: _lerp(a.sm, b.sm, t),
        md: _lerp(a.md, b.md, t),
        lg: _lerp(a.lg, b.lg, t),
        pill: _lerp(a.pill, b.pill, t),
      );
}

/// Motion tokens. Product UI: short, state-conveying transitions.
@immutable
class AppMotion {
  const AppMotion({
    this.fast = const Duration(milliseconds: 120),
    this.base = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
  });

  final Duration fast;
  final Duration base;
  final Duration slow;
  final Curve curve;

  static AppMotion lerp(AppMotion a, AppMotion b, double t) => t < 0.5 ? a : b;
}

/// A semantic color pair: a soft container fill and the ink that reads on it.
@immutable
class ColorPair {
  const ColorPair(this.container, this.on);
  final Color container;
  final Color on;

  static ColorPair lerp(ColorPair a, ColorPair b, double t) => ColorPair(
        Color.lerp(a.container, b.container, t)!,
        Color.lerp(a.on, b.on, t)!,
      );
}

/// Semantic colors for every [TaskState], decoupled from raw Material roles so
/// the meaning of "in progress" or "done" can be tuned in one place.
@immutable
class AppStateColors {
  const AppStateColors({
    required this.todo,
    required this.inProgress,
    required this.awaitingApproval,
    required this.done,
    required this.blocked,
    required this.reTasked,
  });

  final ColorPair todo;
  final ColorPair inProgress;
  final ColorPair awaitingApproval;
  final ColorPair done;
  final ColorPair blocked;
  final ColorPair reTasked;

  ColorPair of(TaskState state) => switch (state) {
        TaskState.todo => todo,
        TaskState.inProgress => inProgress,
        TaskState.awaitingApproval => awaitingApproval,
        TaskState.done => done,
        TaskState.blocked => blocked,
        TaskState.reTasked => reTasked,
      };

  static AppStateColors lerp(AppStateColors a, AppStateColors b, double t) =>
      AppStateColors(
        todo: ColorPair.lerp(a.todo, b.todo, t),
        inProgress: ColorPair.lerp(a.inProgress, b.inProgress, t),
        awaitingApproval:
            ColorPair.lerp(a.awaitingApproval, b.awaitingApproval, t),
        done: ColorPair.lerp(a.done, b.done, t),
        blocked: ColorPair.lerp(a.blocked, b.blocked, t),
        reTasked: ColorPair.lerp(a.reTasked, b.reTasked, t),
      );
}

/// The complete Stepwise design-token bundle, carried on [ThemeData] as a
/// [ThemeExtension] so every widget reads design decisions from one place.
///
/// Iterate on the look by editing the values here (and the palette in
/// `app_theme.dart`); the whole app follows.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.space = const AppSpacing(),
    this.radius = const AppRadius(),
    this.motion = const AppMotion(),
    required this.state,
  });

  final AppSpacing space;
  final AppRadius radius;
  final AppMotion motion;
  final AppStateColors state;

  @override
  AppTokens copyWith({
    AppSpacing? space,
    AppRadius? radius,
    AppMotion? motion,
    AppStateColors? state,
  }) =>
      AppTokens(
        space: space ?? this.space,
        radius: radius ?? this.radius,
        motion: motion ?? this.motion,
        state: state ?? this.state,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      space: AppSpacing.lerp(space, other.space, t),
      radius: AppRadius.lerp(radius, other.radius, t),
      motion: AppMotion.lerp(motion, other.motion, t),
      state: AppStateColors.lerp(state, other.state, t),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Ergonomic access to the design system from any widget:
/// `context.tokens`, `context.colors`, `context.texts`.
extension AppThemeContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      AppTokens(state: _fallbackStateColors(Theme.of(this).colorScheme));
  AppSpacing get space => tokens.space;
  AppRadius get radius => tokens.radius;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;

  /// Vertical gap from the spacing scale.
  SizedBox gapH(double size) => SizedBox(height: size);

  /// Horizontal gap from the spacing scale.
  SizedBox gapW(double size) => SizedBox(width: size);
}

AppStateColors _fallbackStateColors(ColorScheme s) => AppStateColors(
      todo: ColorPair(s.surfaceContainerHighest, s.onSurface),
      inProgress: ColorPair(s.primaryContainer, s.onPrimaryContainer),
      awaitingApproval: ColorPair(s.secondaryContainer, s.onSecondaryContainer),
      done: ColorPair(s.tertiaryContainer, s.onTertiaryContainer),
      blocked: ColorPair(s.errorContainer, s.onErrorContainer),
      reTasked: ColorPair(s.surfaceContainer, s.onSurface),
    );
