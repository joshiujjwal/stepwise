import 'package:flutter/material.dart';

import '../accessibility.dart';
import '../colors.dart';
import '../motion.dart';
import '../progress.dart';
import '../spacing.dart';
import '../typography.dart';

/// Core micro-task card for TinyWins.
class ChunkCard extends StatefulWidget {
  const ChunkCard({
    super.key,
    required this.title,
    required this.description,
    required this.estMinutes,
    this.isDone = false,
    this.onTap,
    this.onToggleDone,
    this.showAccentBar = true,
  });

  final String title;
  final String description;
  final int estMinutes;
  final bool isDone;
  final VoidCallback? onTap;
  final VoidCallback? onToggleDone;
  final bool showAccentBar;

  @override
  State<ChunkCard> createState() => _ChunkCardState();
}

class _ChunkCardState extends State<ChunkCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant ChunkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDone && widget.isDone) {
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
    final spacing = context.twSpacing;
    final progressTheme = context.twProgressTheme;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = 1 + (_pulse.value * (context.reduceMotion ? 0 : 0.015));
        return Transform.scale(scale: scale, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: spacing.cardPadding,
            decoration: BoxDecoration(
              color: TinyWinsColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TinyWinsColors.border),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (widget.showAccentBar) ...<Widget>[
                  Container(
                    width: 4,
                    height: 64,
                    decoration: BoxDecoration(
                      color: widget.isDone
                          ? progressTheme.milestone100
                          : progressTheme.fill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: text.titleMedium.copyWith(
                          decoration:
                              widget.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(widget.description, style: text.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: TinyWinsColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text('${widget.estMinutes} min', style: text.label),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onToggleDone != null)
                  IconButton(
                    onPressed: () {
                      widget.onToggleDone?.call();
                    },
                    icon: Icon(
                      widget.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: widget.isDone
                          ? TinyWinsColors.success
                          : TinyWinsColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
