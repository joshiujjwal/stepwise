import 'package:flutter/foundation.dart';

import '../coordinator/planner.dart';

/// Lifecycle of a background planning job (spec §11, background variant).
///
/// A job is created when the user asks to decompose a goal "in the background";
/// it runs the coordinator off the UI thread and, when finished, waits in a
/// review inbox until the user submits or discards it.
enum PlanningJobStatus {
  /// The coordinator is (or will be) running for this job.
  thinking,

  /// The model returned clarifying questions; the user can answer to refine.
  clarifying,

  /// A validated plan is ready to review, edit, and submit.
  ready,

  /// Planning failed (validation or inference error). Message in [error].
  error,
}

/// One background decomposition request. Immutable; the controller replaces it
/// via [copyWith] as it advances. Persisted so pending/ready plans survive an
/// app restart.
@immutable
class PlanningJob {
  const PlanningJob({
    required this.id,
    required this.goal,
    required this.status,
    required this.createdAt,
    this.questions = const [],
    this.proposal,
    this.error,
  });

  final String id;
  final String goal;
  final PlanningJobStatus status;
  final DateTime createdAt;

  /// Clarifying questions when [status] is [PlanningJobStatus.clarifying].
  final List<String> questions;

  /// The proposed plan when [status] is [PlanningJobStatus.ready].
  final PlanResponse? proposal;

  /// A friendly failure message when [status] is [PlanningJobStatus.error].
  final String? error;

  bool get isReady => status == PlanningJobStatus.ready;

  PlanningJob copyWith({
    PlanningJobStatus? status,
    List<String>? questions,
    PlanResponse? proposal,
    String? error,
  }) =>
      PlanningJob(
        id: id,
        goal: goal,
        status: status ?? this.status,
        createdAt: createdAt,
        questions: questions ?? this.questions,
        proposal: proposal ?? this.proposal,
        error: error,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'goal': goal,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'questions': questions,
        if (proposal != null) 'proposal': proposal!.toMap(),
        if (error != null) 'error': error,
      };

  factory PlanningJob.fromMap(Map<String, Object?> map) => PlanningJob(
        id: map['id'] as String,
        goal: map['goal'] as String,
        status: PlanningJobStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => PlanningJobStatus.error,
        ),
        createdAt: DateTime.parse(map['created_at'] as String),
        questions: [
          for (final q in (map['questions'] as List? ?? const [])) q as String,
        ],
        proposal: map['proposal'] == null
            ? null
            : PlanResponse.fromMap(
                (map['proposal'] as Map).cast<String, Object?>()),
        error: map['error'] as String?,
      );
}
