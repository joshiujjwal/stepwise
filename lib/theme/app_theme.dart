import 'package:flutter/material.dart';

import 'tokens.dart';

/// Stepwise theme.
///
/// Everything visual is composed here from a single [_Palette] per brightness:
/// colors, typography, component shapes, and the [AppTokens] design-token
/// bundle. To restyle the app, edit the palettes and tokens below — screens
/// read from the theme and follow automatically.
ThemeData buildStepwiseTheme() => _build(_Palette.light, Brightness.light);
ThemeData buildStepwiseDarkTheme() => _build(_Palette.dark, Brightness.dark);

const _space = AppSpacing();
const _radius = AppRadius();

ThemeData _build(_Palette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.brand,
    brightness: brightness,
  ).copyWith(
    primary: p.brand,
    onPrimary: p.onBrand,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.inkMuted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surfaceLow,
    surfaceContainer: p.surfaceLow,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.outline,
    outlineVariant: p.outlineVariant,
    error: p.danger,
  );

  final text = _textTheme(scheme);
  final isLight = brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[AppTokens(state: p.state)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: p.ink,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: p.brand.withValues(alpha: isLight ? 0.12 : 0.24),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? p.brand : p.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? p.brand : p.inkMuted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: _radius.lgAll,
        side: BorderSide(color: p.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: _space.lg, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: _radius.mdAll,
        borderSide: BorderSide(color: p.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radius.mdAll,
        borderSide: BorderSide(color: p.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radius.mdAll,
        borderSide: BorderSide(color: p.brand, width: 1.6),
      ),
      hintStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
      labelStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: _space.xl),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: _radius.mdAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: p.brand,
        side: BorderSide(color: p.outline),
        padding: EdgeInsets.symmetric(horizontal: _space.lg),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: _radius.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.brand,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.brand.withValues(alpha: 0.14),
      checkmarkColor: p.brand,
      side: BorderSide(color: p.outlineVariant),
      labelStyle: text.labelLarge?.copyWith(color: p.ink),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: p.brand),
      shape: const StadiumBorder(),
      padding: EdgeInsets.symmetric(horizontal: _space.md, vertical: 6),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: _space.lg, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: _radius.lgAll),
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall?.copyWith(color: p.inkMuted),
    ),
    dividerTheme: DividerThemeData(
      color: p.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: p.surface),
      shape: RoundedRectangleBorder(borderRadius: _radius.mdAll),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.symmetric(horizontal: _space.lg),
      childrenPadding: EdgeInsets.only(bottom: _space.sm),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand),
  );
}

TextTheme _textTheme(ColorScheme scheme) {
  final base = (scheme.brightness == Brightness.dark
          ? Typography.material2021().white
          : Typography.material2021().black)
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return base.copyWith(
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    bodySmall: base.bodySmall?.copyWith(height: 1.35),
    labelLarge: base.labelLarge?.copyWith(letterSpacing: 0),
  );
}

/// A single brightness-scoped palette. Edit these to restyle the whole app.
@immutable
class _Palette {
  const _Palette({
    required this.brand,
    required this.onBrand,
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.ink,
    required this.inkMuted,
    required this.outline,
    required this.outlineVariant,
    required this.danger,
    required this.state,
  });

  final Color brand;
  final Color onBrand;
  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color ink;
  final Color inkMuted;
  final Color outline;
  final Color outlineVariant;
  final Color danger;
  final AppStateColors state;

  // TickTick-inspired warmth: friendly green action accent on warm-neutral surfaces.
  static const light = _Palette(
    brand: Color(0xFF1B824D),
    onBrand: Color(0xFFFFFFFF),
    background: Color(0xFFF7F4EF),
    surface: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF1EDE5),
    surfaceHigh: Color(0xFFE9E3D8),
    ink: Color(0xFF2A2620),
    inkMuted: Color(0xFF6B6358),
    outline: Color(0xFFD8D0C3),
    outlineVariant: Color(0xFFE8E2D6),
    danger: Color(0xFFB4322A),
    state: AppStateColors(
      todo: ColorPair(Color(0xFFEFEAE1), Color(0xFF5C5447)),
      inProgress: ColorPair(Color(0xFFDCEBFB), Color(0xFF1B5C9E)),
      awaitingApproval: ColorPair(Color(0xFFF7E6C4), Color(0xFF7A551A)),
      done: ColorPair(Color(0xFFD8EBD4), Color(0xFF1F5A2C)),
      blocked: ColorPair(Color(0xFFF6DCD5), Color(0xFF8C3326)),
      reTasked: ColorPair(Color(0xFFECE6DC), Color(0xFF5A5346)),
    ),
  );

  static const dark = _Palette(
    brand: Color(0xFF5FC98A),
    onBrand: Color(0xFF07291A),
    background: Color(0xFF15130F),
    surface: Color(0xFF1E1B16),
    surfaceLow: Color(0xFF24201A),
    surfaceHigh: Color(0xFF2D281F),
    ink: Color(0xFFECE6DC),
    inkMuted: Color(0xFFADA597),
    outline: Color(0xFF423C32),
    outlineVariant: Color(0xFF2D281F),
    danger: Color(0xFFF0A79E),
    state: AppStateColors(
      todo: ColorPair(Color(0xFF272219), Color(0xFFCBC4B6)),
      inProgress: ColorPair(Color(0xFF122E47), Color(0xFF8FC4F7)),
      awaitingApproval: ColorPair(Color(0xFF332915), Color(0xFFE9C97E)),
      done: ColorPair(Color(0xFF16301E), Color(0xFF86D69A)),
      blocked: ColorPair(Color(0xFF3A201D), Color(0xFFF0A79E)),
      reTasked: ColorPair(Color(0xFF2A251D), Color(0xFFC2BBAD)),
    ),
  );
}
