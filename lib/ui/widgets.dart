import 'package:flutter/material.dart';

import '../models/models.dart';

String stateLabel(TaskState s) => switch (s) {
      TaskState.todo => 'To do',
      TaskState.inProgress => 'In progress',
      TaskState.awaitingApproval => 'Awaiting approval',
      TaskState.done => 'Done',
      TaskState.blocked => 'Blocked',
      TaskState.reTasked => 'Re-tasked',
    };

Color stateColor(BuildContext context, TaskState s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    TaskState.todo => scheme.surfaceContainerHighest,
    TaskState.inProgress => scheme.primaryContainer,
    TaskState.awaitingApproval => scheme.secondaryContainer,
    TaskState.done => scheme.tertiaryContainer,
    TaskState.blocked => scheme.errorContainer,
    TaskState.reTasked => scheme.surfaceContainer,
  };
}

Color stateOnColor(BuildContext context, TaskState s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    TaskState.todo => scheme.onSurface,
    TaskState.inProgress => scheme.onPrimaryContainer,
    TaskState.awaitingApproval => scheme.onSecondaryContainer,
    TaskState.done => scheme.onTertiaryContainer,
    TaskState.blocked => scheme.onErrorContainer,
    TaskState.reTasked => scheme.onSurface,
  };
}

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
    final bg = stateColor(context, state);
    final fg = stateOnColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stateIcon(state), size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            stateLabel(state),
            style: TextStyle(fontSize: 12, color: fg),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$estMinutes min',
        style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer),
      ),
    );
  }
}
