import 'package:flutter/material.dart';

/// Motion tokens for TinyWins interactions.
abstract final class TwMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve emphasizedOut = Curves.easeOutCubic;
  static const Curve standardOut = Curves.easeOut;
}

extension TwMotionContext on BuildContext {
  bool get reduceMotion {
    final media = MediaQuery.maybeOf(this);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  Duration motionDuration(Duration duration) {
    if (reduceMotion) return Duration.zero;
    return duration;
  }
}
