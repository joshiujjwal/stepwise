import 'package:flutter/material.dart';

import '../accessibility.dart';
import '../colors.dart';
import '../motion.dart';
import '../progress.dart';
import '../spacing.dart';
import '../typography.dart';

/// Compact counter that celebrates completed wins.
class WinCounter extends StatefulWidget {
  const WinCounter({
    super.key,
    required this.count,
    this.label = 'Wins earned',
  });

  final int count;
  final String label;

  @override
  State<WinCounter> createState() => _WinCounterState();
}

class _WinCounterState extends State<WinCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void didUpdateWidget(covariant WinCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      TwA11y.celebrateWin();
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.twText;
    final progressTheme = context.twProgressTheme;
    final milestoneColor = progressTheme.milestoneFor(
      widget.count <= 0 ? 0 : (widget.count >= 4 ? 1 : widget.count / 4),
    );
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = 1 + (_pulse.value * (context.reduceMotion ? 0 : 0.04));
        return Transform.scale(scale: scale, child: child);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: TinyWinsGradients.hero,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14059669),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.emoji_events_rounded, color: Colors.white),
              const TwGap.h(TwSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${widget.count}',
                    style: text.headline.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.label,
                    style: text.label.copyWith(
                      color: const Color(0xFFE6FFFA),
                    ),
                  ),
                ],
              ),
              const TwGap.h(TwSpacing.md),
              Icon(
                Icons.flash_on_rounded,
                color: milestoneColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
