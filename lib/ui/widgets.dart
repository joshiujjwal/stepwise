import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

String stateLabel(TaskState s) => switch (s) {
      TaskState.todo => 'To do',
      TaskState.inProgress => 'In progress',
      TaskState.awaitingApproval => 'Awaiting approval',
      TaskState.done => 'Done',
      TaskState.blocked => 'Blocked',
      TaskState.reTasked => 'Re-tasked',
    };

/// Semantic fill for a task state, sourced from the design tokens.
Color stateColor(BuildContext context, TaskState s) =>
    context.tokens.state.of(s).container;

/// Ink that reads on [stateColor] for the same state.
Color stateOnColor(BuildContext context, TaskState s) =>
    context.tokens.state.of(s).on;

IconData stateIcon(TaskState s) => switch (s) {
      TaskState.todo => Icons.radio_button_unchecked,
      TaskState.inProgress => Icons.play_circle_outline,
      TaskState.awaitingApproval => Icons.fact_check_outlined,
      TaskState.done => Icons.check_circle_outline,
      TaskState.blocked => Icons.block_outlined,
      TaskState.reTasked => Icons.call_split,
    };

class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});
  final TaskState state;

  @override
  Widget build(BuildContext context) {
    final pair = context.tokens.state.of(state);
    final space = context.space;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: space.md, vertical: 6),
      decoration: BoxDecoration(
        color: pair.container,
        borderRadius: context.radius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stateIcon(state), size: 14, color: pair.on),
          SizedBox(width: space.xs),
          Text(
            stateLabel(state),
            style: context.texts.labelMedium?.copyWith(color: pair.on),
          ),
        ],
      ),
    );
  }
}

class DurationBadge extends StatelessWidget {
  const DurationBadge(this.estMinutes, {super.key});
  final int estMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.space.md, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: context.radius.pillAll,
      ),
      child: Text(
        '$estMinutes min',
        style: context.texts.labelMedium?.copyWith(
          color: context.colors.onSurface,
        ),
      ),
    );
  }
}

/// Title + optional supporting line used at the top of each tab body.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.texts.titleLarge),
        if (subtitle != null) ...[
          SizedBox(height: context.space.xs),
          Text(
            subtitle!,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// A titled content card. The standard container for grouped information.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.texts.titleMedium),
            SizedBox(height: space.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// A single headline metric (value over label) for stat rows.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.space.md,
          vertical: context.space.lg,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: context.texts.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: context.space.xs),
            Text(
              label,
              style: context.texts.labelMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
