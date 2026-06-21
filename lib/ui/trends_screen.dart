import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_scope.dart';
import '../state/projections.dart';

/// Trends - throughput, streak, completion rate, estimate-vs-actual calibration,
/// and a friction map. All projected from the event log (spec sections 5/6).
/// Wireframe: docs/wireframes/3-trends.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    final events = controller.store.events;
    final tasks = controller.allTasks;

    final throughput = throughputByDay(events);
    final streak = currentStreak(events, today: DateTime.now());
    final friction = frictionCounts(events);
    final points = calibration(tasks);

    final leaves = tasks.where((t) => t.state != TaskState.reTasked).toList();
    final done = leaves.where((t) => t.state == TaskState.done).length;
    final completion =
        leaves.isEmpty ? 0 : ((done / leaves.length) * 100).round();
    final totalDone = throughput.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Track how you earn wins over time from your event timeline.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stat(context, 'Streak', '$streak d')),
              const SizedBox(width: 12),
              Expanded(child: _stat(context, 'Completed', '$totalDone')),
              const SizedBox(width: 12),
              Expanded(child: _stat(context, 'Completion', '$completion%')),
            ],
          ),
          const SizedBox(height: 16),
          _card(
              'Where you get stuck',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Blocked: ${friction.blocked}'),
                  Text('Re-tasked: ${friction.reTasked}'),
                  Text('Rejected: ${friction.rejected}'),
                ],
              )),
          const SizedBox(height: 16),
          _card(
            'Estimate vs actual',
            points.isEmpty
                ? Text(
                    'Run the focus timer to see your calibration.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in points)
                        Text('est ${p.estMinutes}m  ->  actual '
                            '${p.actualMinutes}m'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
