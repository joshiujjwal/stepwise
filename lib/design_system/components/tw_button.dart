import 'package:flutter/material.dart';

import '../accessibility.dart';
import '../component_states.dart';
import '../colors.dart';
import '../motion.dart';

enum TwButtonVariant { primary, secondary, success }

/// TinyWins button with consistent shape, spacing, and state handling.
class TwButton extends StatelessWidget {
  const TwButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TwButtonVariant.primary,
    this.isLoading = false,
    this.expanded = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final TwButtonVariant variant;
  final bool isLoading;
  final bool expanded;
  final IconData? icon;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final states = context.twControlStates;
    final duration = context.motionDuration(TwMotion.normal);
    final child = AnimatedSwitcher(
      duration: duration,
      switchInCurve: TwMotion.emphasizedOut,
      switchOutCurve: TwMotion.emphasizedOut,
      child: isLoading
          ? const SizedBox(
              key: ValueKey<String>('loader'),
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Row(
              key: const ValueKey<String>('content'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );

    final widget = switch (variant) {
      TwButtonVariant.secondary => OutlinedButton(
          onPressed: _enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: TinyWinsColors.primaryGreen,
            side: const BorderSide(color: TinyWinsColors.primaryGreen),
          ),
          child: child,
        ),
      TwButtonVariant.success => FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: states.successBg,
            foregroundColor: Colors.white,
          ),
          child: child,
        ),
      TwButtonVariant.primary => FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: states.defaultBg,
            foregroundColor: states.defaultFg,
            disabledBackgroundColor: states.disabledBg,
            disabledForegroundColor: states.disabledFg,
          ),
          child: child,
        ),
    };

    final constrained = TwMinTapTarget(child: widget);
    if (!expanded) return constrained;
    return SizedBox(width: double.infinity, child: constrained);
  }
}
