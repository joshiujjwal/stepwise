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
              Expanded(
                child: StatCard(
                  label: 'Streak',
                  value: '$streak d',
                  accent: streak > 0 ? context.colors.primary : null,
                ),
              ),
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
            title: 'Completion',
            child: _CompletionMeter(done: done, total: leaves.length),
          ),
          SizedBox(height: space.lg),
          SectionCard(
            title: 'Where you get stuck',
            child: _FrictionMap(friction: friction),
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
                : _CalibrationChart(points: points),
          ),
        ],
      ),
    );
  }
}

/// Done-out-of-total as an encouraging brand-green meter.
class _CompletionMeter extends StatelessWidget {
  const _CompletionMeter({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0
              ? 'No micro tasks yet — add an idea to start earning wins.'
              : '$done of $total micro tasks done',
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        SizedBox(height: space.md),
        ProgressBar(
          value: ratio,
          height: 10,
          semanticLabel: 'Completion',
        ),
      ],
    );
  }
}

/// Friction counts, each keyed to its own semantic state color so a glance
/// tells you where the drag is. Colour is redundant with the label and count.
class _FrictionMap extends StatelessWidget {
  const _FrictionMap({required this.friction});
  final FrictionCounts friction;

  @override
  Widget build(BuildContext context) {
    final state = context.tokens.state;
    final total = friction.blocked + friction.reTasked + friction.rejected;
    if (total == 0) {
      return Text(
        'No friction yet — smooth going. Keep the momentum.',
        style: context.texts.bodyMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        _FrictionRow(
          label: 'Blocked',
          count: friction.blocked,
          color: state.blocked.on,
        ),
        _FrictionRow(
          label: 'Re-tasked',
          count: friction.reTasked,
          color: state.reTasked.on,
        ),
        _FrictionRow(
          label: 'Rejected',
          count: friction.rejected,
          color: state.awaitingApproval.on,
        ),
      ],
    );
  }
}

class _FrictionRow extends StatelessWidget {
  const _FrictionRow({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final active = count > 0;
    final dot = active ? color : context.colors.outline;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: space.xs),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: space.md),
          Expanded(child: Text(label, style: context.texts.bodyMedium)),
          Text(
            '$count',
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? color : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estimate-vs-actual as paired bars on a shared scale. The actual bar is green
/// when you landed on or under estimate, amber when the task ran long.
class _CalibrationChart extends StatelessWidget {
  const _CalibrationChart({required this.points});
  final List<CalibrationPoint> points;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final state = context.tokens.state;
    final max = points.fold<int>(
      1,
      (m, p) =>
          [m, p.estMinutes, p.actualMinutes].reduce((a, b) => a > b ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in points) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: space.sm),
            child: _CalibrationRow(
              point: p,
              max: max,
              onTrackColor: state.done.on,
              overColor: state.awaitingApproval.on,
            ),
          ),
        ],
      ],
    );
  }
}

class _CalibrationRow extends StatelessWidget {
  const _CalibrationRow({
    required this.point,
    required this.max,
    required this.onTrackColor,
    required this.overColor,
  });
  final CalibrationPoint point;
  final int max;
  final Color onTrackColor;
  final Color overColor;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final overrun = point.actualMinutes > point.estMinutes;
    final actualColor = overrun ? overColor : onTrackColor;
    final labelStyle = context.texts.labelSmall
        ?.copyWith(color: context.colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 52, child: Text('estimate', style: labelStyle)),
            Expanded(
              child: ProgressBar(
                value: point.estMinutes / max,
                height: 8,
                color: context.colors.outline,
                semanticLabel: 'Estimate',
              ),
            ),
            SizedBox(width: space.sm),
            Text('${point.estMinutes}m', style: labelStyle),
          ],
        ),
        SizedBox(height: space.xs),
        Row(
          children: [
            SizedBox(width: 52, child: Text('actual', style: labelStyle)),
            Expanded(
              child: ProgressBar(
                value: point.actualMinutes / max,
                height: 8,
                color: actualColor,
                semanticLabel: 'Actual',
              ),
            ),
            SizedBox(width: space.sm),
            Text(
              '${point.actualMinutes}m',
              style: context.texts.labelSmall?.copyWith(
                color: actualColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
