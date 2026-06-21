import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Accessibility helpers and constants for TinyWins controls.
abstract final class TwA11y {
  static const double minTapTarget = 44;
  static const int maxBodyCharsPerLine = 72;

  static Future<void> celebrateWin() => HapticFeedback.lightImpact();
}

class TwMinTapTarget extends StatelessWidget {
  const TwMinTapTarget({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TwA11y.minTapTarget,
        minHeight: TwA11y.minTapTarget,
      ),
      child: child,
    );
  }
}
