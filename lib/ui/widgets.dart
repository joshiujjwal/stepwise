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

Color stateColor(TaskState s) => switch (s) {
      TaskState.todo => const Color(0xFFE9ECEF),
      TaskState.inProgress => const Color(0xFFA5D8FF),
      TaskState.awaitingApproval => const Color(0xFFFFEC99),
      TaskState.done => const Color(0xFFB2F2BB),
      TaskState.blocked => const Color(0xFFFFC9C9),
      TaskState.reTasked => const Color(0xFFD0BFFF),
    };

class StatePill extends StatelessWidget {
  const StatePill(this.state, {super.key});
  final TaskState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: stateColor(state),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        stateLabel(state),
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E1E1E)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA5D8FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$estMinutes min',
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E1E1E)),
      ),
    );
  }
}
