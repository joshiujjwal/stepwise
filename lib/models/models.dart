// Domain models for stepwise. See docs/spec.md (§1) for the full data model.
// Intentionally simple, immutable-by-default value types. Persistence
// (event-sourced store) and serialization are wired in Phase 0-2.

enum IdeaType { tax, trip, errand, admin, project, other }

enum IdeaStatus { planning, active, stalled, done }

/// Micro-task lifecycle (spec §2).
enum TaskState { todo, inProgress, awaitingApproval, done, blocked, reTasked }

enum EvidenceType { checkbox, note, url, file }

/// Time buckets behind the "What can I do in 15 min?" filter (spec §5).
enum DurationBucket {
  m15,
  m30,
  m45,
  m60plus;

  /// Derive the bucket from an estimate. Mirrors `duration_bucket()` in
  /// tool/coordinator/validate_plan.py.
  static DurationBucket fromMinutes(int estMinutes) {
    if (estMinutes <= 15) return DurationBucket.m15;
    if (estMinutes <= 30) return DurationBucket.m30;
    if (estMinutes <= 45) return DurationBucket.m45;
    return DurationBucket.m60plus;
  }

  String get label => switch (this) {
        DurationBucket.m15 => '15 min',
        DurationBucket.m30 => '30 min',
        DurationBucket.m45 => '45 min',
        DurationBucket.m60plus => '60+ min',
      };
}

/// A checkable "definition of done" item (spec §3). Checkbox by default.
class AcceptanceCriterion {
  const AcceptanceCriterion({
    required this.id,
    required this.text,
    this.evidenceType = EvidenceType.checkbox,
    this.satisfied = false,
    this.evidenceValue,
  });

  final String id;
  final String text;
  final EvidenceType evidenceType;
  final bool satisfied;
  final String? evidenceValue;

  AcceptanceCriterion copyWith({bool? satisfied, String? evidenceValue}) {
    return AcceptanceCriterion(
      id: id,
      text: text,
      evidenceType: evidenceType,
      satisfied: satisfied ?? this.satisfied,
      evidenceValue: evidenceValue ?? this.evidenceValue,
    );
  }
}

class MicroTask {
  const MicroTask({
    required this.id,
    required this.ideaId,
    required this.title,
    required this.description,
    required this.estMinutes,
    required this.orderIndex,
    required this.acceptanceCriteria,
    this.state = TaskState.todo,
    this.parentTaskId,
    this.scheduledStart,
    this.focusSeconds = 0,
  });

  final String id;
  final String ideaId;
  final String? parentTaskId;
  final String title;
  final String description;
  final int estMinutes;
  final int orderIndex;
  final DateTime? scheduledStart;
  final TaskState state;
  final List<AcceptanceCriterion> acceptanceCriteria;
  final int focusSeconds;

  DurationBucket get durationBucket => DurationBucket.fromMinutes(estMinutes);

  /// The guard for `done`: every acceptance criterion is satisfied (spec §3).
  bool get allCriteriaSatisfied => acceptanceCriteria.every((c) => c.satisfied);

  MicroTask copyWith({
    TaskState? state,
    int? focusSeconds,
    DateTime? scheduledStart,
    List<AcceptanceCriterion>? acceptanceCriteria,
  }) {
    return MicroTask(
      id: id,
      ideaId: ideaId,
      parentTaskId: parentTaskId,
      title: title,
      description: description,
      estMinutes: estMinutes,
      orderIndex: orderIndex,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      state: state ?? this.state,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      focusSeconds: focusSeconds ?? this.focusSeconds,
    );
  }
}

class Idea {
  const Idea({
    required this.id,
    required this.title,
    required this.rawInput,
    required this.type,
    required this.createdAt,
    this.status = IdeaStatus.planning,
    this.planVersion = 1,
  });

  final String id;
  final String title;
  final String rawInput;
  final IdeaType type;
  final IdeaStatus status;
  final int planVersion;
  final DateTime createdAt;
}

/// An append-only event (spec §1). Task state and trends are projections of these.
class EventRecord {
  const EventRecord({
    required this.id,
    required this.ideaId,
    required this.type,
    required this.actor,
    required this.ts,
    this.microTaskId,
    this.fromState,
    this.toState,
    this.payload = const {},
  });

  final String id;
  final String ideaId;
  final String? microTaskId;
  final String type; // e.g. 'task_approved', 'plan_confirmed', 'timer_started'
  final String actor; // 'user' | 'coordinator'
  final TaskState? fromState;
  final TaskState? toState;
  final Map<String, Object?> payload;
  final DateTime ts;
}
