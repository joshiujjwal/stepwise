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

  Map<String, Object?> toMap() => {
        'id': id,
        'text': text,
        'evidenceType': evidenceType.name,
        'satisfied': satisfied,
        'evidenceValue': evidenceValue,
      };

  factory AcceptanceCriterion.fromMap(Map<String, Object?> map) {
    return AcceptanceCriterion(
      id: map['id']! as String,
      text: map['text']! as String,
      evidenceType: _enumByName(
          EvidenceType.values, map['evidenceType'], EvidenceType.checkbox),
      satisfied: (map['satisfied'] as bool?) ?? false,
      evidenceValue: map['evidenceValue'] as String?,
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

  Map<String, Object?> toMap() => {
        'id': id,
        'ideaId': ideaId,
        'parentTaskId': parentTaskId,
        'title': title,
        'description': description,
        'estMinutes': estMinutes,
        'orderIndex': orderIndex,
        'scheduledStart': scheduledStart?.toIso8601String(),
        'state': state.name,
        'focusSeconds': focusSeconds,
        'acceptanceCriteria': [
          for (final c in acceptanceCriteria) c.toMap(),
        ],
      };

  factory MicroTask.fromMap(Map<String, Object?> map) {
    final rawCriteria =
        (map['acceptanceCriteria'] as List<Object?>?) ?? const [];
    return MicroTask(
      id: map['id']! as String,
      ideaId: map['ideaId']! as String,
      parentTaskId: map['parentTaskId'] as String?,
      title: map['title']! as String,
      description: (map['description'] as String?) ?? '',
      estMinutes: (map['estMinutes'] as num).toInt(),
      orderIndex: (map['orderIndex'] as num).toInt(),
      scheduledStart: _parseDate(map['scheduledStart']),
      state: _enumByName(TaskState.values, map['state'], TaskState.todo),
      focusSeconds: (map['focusSeconds'] as num?)?.toInt() ?? 0,
      acceptanceCriteria: [
        for (final c in rawCriteria)
          AcceptanceCriterion.fromMap((c as Map).cast<String, Object?>()),
      ],
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

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'rawInput': rawInput,
        'type': type.name,
        'status': status.name,
        'planVersion': planVersion,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Idea.fromMap(Map<String, Object?> map) {
    return Idea(
      id: map['id']! as String,
      title: map['title']! as String,
      rawInput: (map['rawInput'] as String?) ?? '',
      type: _enumByName(IdeaType.values, map['type'], IdeaType.other),
      status:
          _enumByName(IdeaStatus.values, map['status'], IdeaStatus.planning),
      planVersion: (map['planVersion'] as num?)?.toInt() ?? 1,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }
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

  Map<String, Object?> toMap() => {
        'id': id,
        'ideaId': ideaId,
        'microTaskId': microTaskId,
        'type': type,
        'actor': actor,
        'fromState': fromState?.name,
        'toState': toState?.name,
        'payload': Map<String, Object?>.from(payload),
        'ts': ts.toIso8601String(),
      };

  factory EventRecord.fromMap(Map<String, Object?> map) {
    final rawPayload = map['payload'];
    return EventRecord(
      id: map['id']! as String,
      ideaId: map['ideaId']! as String,
      microTaskId: map['microTaskId'] as String?,
      type: map['type']! as String,
      actor: map['actor']! as String,
      fromState: _nullableEnumByName(TaskState.values, map['fromState']),
      toState: _nullableEnumByName(TaskState.values, map['toState']),
      payload: rawPayload is Map
          ? rawPayload.cast<String, Object?>()
          : const <String, Object?>{},
      ts: _parseDate(map['ts']) ?? DateTime.now(),
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? _nullableEnumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
