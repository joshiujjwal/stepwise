import '../models/models.dart';
import 'event_store.dart';

// Pure projection functions over the event log and current entities.
// Everything here is deterministic and unit-tested (no I/O, no clock unless
// passed in). These power the progress view (spec §6) and trends (spec §5/§6).

/// Progress of a single idea, derived from its (leaf) tasks.
class IdeaProgress {
  const IdeaProgress({
    required this.total,
    required this.done,
    required this.currentStep,
  });

  /// Number of leaf tasks (re-tasked containers are excluded by the caller).
  final int total;
  final int done;

  /// 1-based index of the first not-done task by suggested order, or [total]+0
  /// when all are done (then [currentStep] == total and [isComplete] is true).
  final int currentStep;

  bool get isComplete => total > 0 && done == total;

  /// 0..100, rounded.
  int get percentComplete => total == 0 ? 0 : ((done / total) * 100).round();

  @override
  String toString() =>
      'IdeaProgress(step $currentStep of $total, $percentComplete%)';
}

/// Compute progress from a task list. Order is advisory; "current step" is the
/// first not-done task in suggested order (spec §6).
IdeaProgress progressFor(List<MicroTask> tasks) {
  final leaves = tasks
      .where((t) => t.state != TaskState.reTasked)
      .toList(growable: false)
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final total = leaves.length;
  final done = leaves.where((t) => t.state == TaskState.done).length;
  if (total == 0) return const IdeaProgress(total: 0, done: 0, currentStep: 0);
  final idx = leaves.indexWhere((t) => t.state != TaskState.done);
  final currentStep = idx == -1 ? total : idx + 1;
  return IdeaProgress(total: total, done: done, currentStep: currentStep);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Tasks completed per calendar day (local), from `task_approved` events.
Map<DateTime, int> throughputByDay(List<EventRecord> events) {
  final out = <DateTime, int>{};
  for (final e in events) {
    if (e.type == EventTypes.taskApproved) {
      final day = _dateOnly(e.ts);
      out[day] = (out[day] ?? 0) + 1;
    }
  }
  return out;
}

/// Consecutive days up to [today] with at least one completed task.
int currentStreak(List<EventRecord> events, {required DateTime today}) {
  final days = throughputByDay(events).keys.toSet();
  var streak = 0;
  var cursor = _dateOnly(today);
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Friction signals from the event log (spec §6 "where you get stuck").
class FrictionCounts {
  const FrictionCounts({
    required this.blocked,
    required this.reTasked,
    required this.rejected,
  });
  final int blocked;
  final int reTasked;
  final int rejected;
}

FrictionCounts frictionCounts(List<EventRecord> events) {
  var blocked = 0, reTasked = 0, rejected = 0;
  for (final e in events) {
    switch (e.type) {
      case EventTypes.taskBlocked:
        blocked++;
      case EventTypes.taskRetasked:
        reTasked++;
      case EventTypes.taskRejected:
        rejected++;
    }
  }
  return FrictionCounts(
    blocked: blocked,
    reTasked: reTasked,
    rejected: rejected,
  );
}

/// One estimate-vs-actual data point (spec §6 calibration). Actual is focused
/// time from the optional timer; tasks without timer use are excluded.
class CalibrationPoint {
  const CalibrationPoint({
    required this.taskId,
    required this.estMinutes,
    required this.actualMinutes,
  });
  final String taskId;
  final int estMinutes;
  final int actualMinutes;
}

List<CalibrationPoint> calibration(List<MicroTask> tasks) {
  return [
    for (final t in tasks)
      if (t.state == TaskState.done && t.focusSeconds > 0)
        CalibrationPoint(
          taskId: t.id,
          estMinutes: t.estMinutes,
          actualMinutes: (t.focusSeconds / 60).round(),
        ),
  ];
}
