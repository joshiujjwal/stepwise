import 'package:flutter/material.dart';

/// Execute tab - actionable tasks with a duration filter, plus a List <-> Calendar
/// toggle. Wireframes: docs/wireframes/1-do-next (list) and 5-calendar-day (calendar).
/// Spec §6 and §11.
class ExecuteScreen extends StatelessWidget {
  const ExecuteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execute')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'What can you do right now?\n\n'
            'TODO (Phase 1-2): duration filter (15/30/45), Do-Next list, '
            'List <-> Calendar toggle (day timeline), focus timer.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
