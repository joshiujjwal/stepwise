import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_scope.dart';
import '../state/projections.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Trends - throughput, streak, completion rate, estimate-vs-actual calibration,
/// and a friction map. All projected from the event log (spec sections 5/6).
/// Wireframe: docs/wireframes/3-trends.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final space = context.space;
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
        padding: EdgeInsets.all(space.lg),
        children: [
          const ScreenHeader(
            title: 'Trends',
            subtitle:
                'Track how you earn wins over time from your event timeline.',
          ),
          SizedBox(height: space.lg),
          Row(
            children: [
              Expanded(child: StatCard(label: 'Streak', value: '$streak d')),
              SizedBox(width: space.md),
              Expanded(
                  child: StatCard(label: 'Completed', value: '$totalDone')),
              SizedBox(width: space.md),
              Expanded(
                  child: StatCard(label: 'Completion', value: '$completion%')),
            ],
          ),
          SizedBox(height: space.lg),
          SectionCard(
            title: 'Where you get stuck',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blocked: ${friction.blocked}',
                    style: context.texts.bodyMedium),
                Text('Re-tasked: ${friction.reTasked}',
                    style: context.texts.bodyMedium),
                Text('Rejected: ${friction.rejected}',
                    style: context.texts.bodyMedium),
              ],
            ),
          ),
          SizedBox(height: space.lg),
          SectionCard(
            title: 'Estimate vs actual',
            child: points.isEmpty
                ? Text(
                    'Run the focus timer to see your calibration.',
                    style: context.texts.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in points)
                        Text(
                          'est ${p.estMinutes}m  ->  actual ${p.actualMinutes}m',
                          style: context.texts.bodyMedium,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
