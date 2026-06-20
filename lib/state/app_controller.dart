import 'package:flutter/foundation.dart';

import '../coordinator/planner.dart';
import '../coordinator/todo_chunking_agent.dart';
import '../models/models.dart';
import 'event_store.dart';
import 'projections.dart';
import 'task_state_machine.dart';

/// Where the Idea-tab conversation is in its lifecycle (spec §11).
enum PlanningPhase { idle, thinking, clarifying, proposed, error }

/// Transient state of an in-progress idea capture conversation.
@immutable
class PlanningSession {
  const PlanningSession({
    required this.goal,
    this.phase = PlanningPhase.thinking,
    this.questions = const [],
    this.proposal,
    this.error,
  });

  final String goal;
  final PlanningPhase phase;
  final List<String> questions;
  final PlanResponse? proposal;
  final String? error;

  PlanningSession copyWith({
    PlanningPhase? phase,
    List<String>? questions,
    PlanResponse? proposal,
    String? error,
  }) {
    return PlanningSession(
      goal: goal,
      phase: phase ?? this.phase,
      questions: questions ?? this.questions,
      proposal: proposal ?? this.proposal,
      error: error,
    );
  }
}

/// The single source of truth the UI talks to. Holds current entities, drives
/// the coordinator, and appends an event for every mutation (spec §1-§2).
///
/// Note on event-sourcing scope (v1): the authoritative *entity* state
/// (`_ideas`, `_tasks`) is held in memory and mutated directly; the event log is
/// an append-only history that powers trends/projections (see projections.dart).
/// State is NOT yet rebuilt by replaying events. When persistence lands (sqflite,
/// parking lot), add a `hydrateFromEvents` path that replays the log to
/// reconstruct entities on startup.
class AppController extends ChangeNotifier {
  AppController({
    required this.coordinator,
    this.todoChunkingAgent,
    EventStore? store,
    String Function()? idGen,
    DateTime Function()? clock,
  })  : store = store ?? InMemoryEventStore(),
        _idGen = idGen,
        _clock = clock;

  final Coordinator coordinator;
  final TodoChunkingAgent? todoChunkingAgent;
  final EventStore store;
  final String Function()? _idGen;
  final DateTime Function()? _clock;

  int _seq = 0;
  String _newId() => _idGen?.call() ?? 'id${_seq++}';
  DateTime _now() => _clock?.call() ?? DateTime.now();

  final List<Idea> _ideas = [];
  final List<MicroTask> _tasks = [];
  final Map<String, DateTime> _timerRunning = {};
  PlanningSession? _session;

  // ---- read API (for the UI) ----
  List<Idea> get ideas => List.unmodifiable(_ideas);
  PlanningSession? get session => _session;

  List<MicroTask> get allTasks => List.unmodifiable(_tasks);

  List<MicroTask> tasksForIdea(String ideaId) =>
      (_tasks.where((t) => t.ideaId == ideaId).toList())
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  /// Actionable tasks across all ideas (not done, not a re-tasked container),
  /// optionally filtered to a duration bucket. Order is advisory (spec §6).
  List<MicroTask> availableTasks({DurationBucket? bucket}) {
    final out = _tasks.where((t) =>
        t.state != TaskState.done &&
        t.state != TaskState.reTasked &&
        (bucket == null || t.durationBucket == bucket));
    return out.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  IdeaProgress progressForIdea(String ideaId) =>
      progressFor(tasksForIdea(ideaId));

  bool isTimerRunning(String taskId) => _timerRunning.containsKey(taskId);

  MicroTask taskById(String id) => _tasks.firstWhere((t) => t.id == id);

  // ---- idea capture (conversational, spec §4/§11) ----
  Future<void> submitGoal(String goal) async {
    _session = PlanningSession(goal: goal);
    notifyListeners();
    await _runPlanner(goal, 'none');
  }

  /// TODO-first flow: the user writes one TODO item and the dedicated agent
  /// enhances/splits it into time-boxed executable chunks.
  Future<void> submitTodoItem(String todoItem) async {
    _session = PlanningSession(goal: todoItem);
    notifyListeners();

    final agent = todoChunkingAgent;
    if (agent == null) {
      await _runPlanner(todoItem, 'none');
      return;
    }

    try {
      final proposal = await agent.chunkTodo(todoItem);
      _session = _session!.copyWith(
        phase: PlanningPhase.proposed,
        proposal: proposal,
      );
    } on CoordinatorException catch (e) {
      _session = _session!.copyWith(
        phase: PlanningPhase.error,
        error: e.errors.join('; '),
      );
    } catch (e) {
      _session = _session!.copyWith(
        phase: PlanningPhase.error,
        error: e.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> submitAnswers(String answers) async {
    final s = _session;
    if (s == null) return;
    _session = s.copyWith(phase: PlanningPhase.thinking);
    notifyListeners();
    await _runPlanner(s.goal, answers.isEmpty ? 'none' : answers);
  }

  Future<void> _runPlanner(String goal, String answers) async {
    try {
      final resp = await coordinator.plan(goal: goal, priorAnswers: answers);
      _session = switch (resp) {
        ClarifyResponse(:final questions) => _session!
            .copyWith(phase: PlanningPhase.clarifying, questions: questions),
        PlanResponse() =>
          _session!.copyWith(phase: PlanningPhase.proposed, proposal: resp),
      };
    } on CoordinatorException catch (e) {
      _session = _session!.copyWith(
        phase: PlanningPhase.error,
        error: e.errors.join('; '),
      );
    } catch (e) {
      _session = _session!.copyWith(
        phase: PlanningPhase.error,
        error: e.toString(),
      );
    }
    notifyListeners();
  }

  /// Persist the proposed plan as an idea + micro-tasks. Returns the new idea.
  Idea confirmPlan() {
    final s = _session;
    final proposal = s?.proposal;
    if (s == null || proposal == null) {
      throw StateError('no proposed plan to confirm');
    }
    final idea = Idea(
      id: _newId(),
      title: s.goal,
      rawInput: s.goal,
      type: _typeFrom(proposal.ideaType),
      status: IdeaStatus.active,
      createdAt: _now(),
    );
    _ideas.add(idea);
    _append(idea.id, EventTypes.ideaCreated);
    _append(idea.id, EventTypes.planConfirmed,
        payload: {'taskCount': proposal.tasks.length});
    for (final pt in proposal.tasks) {
      _tasks.add(_materialize(idea.id, null, pt));
    }
    _session = null;
    notifyListeners();
    return idea;
  }

  void discardPlan() {
    _session = null;
    notifyListeners();
  }

  // ---- task lifecycle (spec §2) ----
  bool startTask(String id) =>
      _transition(id, TaskState.inProgress, EventTypes.taskStarted);

  bool submitTask(String id) =>
      _transition(id, TaskState.awaitingApproval, EventTypes.taskSubmitted);

  /// Guarded: only succeeds when all acceptance criteria are satisfied (spec §3).
  bool approveTask(String id) {
    final ok = _transition(id, TaskState.done, EventTypes.taskApproved);
    if (ok) _recomputeIdeaStatus(taskById(id).ideaId);
    return ok;
  }

  bool rejectTask(String id) =>
      _transition(id, TaskState.inProgress, EventTypes.taskRejected);

  bool blockTask(String id, String reason) {
    final ok = _transition(id, TaskState.blocked, EventTypes.taskBlocked,
        payload: {'reason': reason});
    if (ok) _recomputeIdeaStatus(taskById(id).ideaId);
    return ok;
  }

  void satisfyCriterion(String taskId, String criterionId,
      {String? evidenceValue}) {
    final i = _indexOf(taskId);
    final t = _tasks[i];
    _tasks[i] = t.copyWith(
      acceptanceCriteria: [
        for (final c in t.acceptanceCriteria)
          if (c.id == criterionId)
            c.copyWith(satisfied: true, evidenceValue: evidenceValue)
          else
            c,
      ],
    );
    _append(t.ideaId, EventTypes.criterionSatisfied,
        microTaskId: taskId, payload: {'criterionId': criterionId});
    notifyListeners();
  }

  void scheduleTask(String taskId, DateTime start) {
    final i = _indexOf(taskId);
    _tasks[i] = _tasks[i].copyWith(scheduledStart: start);
    _append(_tasks[i].ideaId, EventTypes.taskScheduled,
        microTaskId: taskId, payload: {'start': start.toIso8601String()});
    notifyListeners();
  }

  // ---- focus timer (spec §5) ----
  void startTimer(String taskId) {
    if (_timerRunning.containsKey(taskId)) return;
    _timerRunning[taskId] = _now();
    _append(taskById(taskId).ideaId, EventTypes.timerStarted,
        microTaskId: taskId);
    notifyListeners();
  }

  /// Stop the timer and fold elapsed focused seconds into the task.
  void stopTimer(String taskId) {
    final started = _timerRunning.remove(taskId);
    if (started == null) return;
    final elapsed = _now().difference(started).inSeconds;
    final seconds = elapsed < 0 ? 0 : elapsed; // guard clock skew
    final i = _indexOf(taskId);
    _tasks[i] = _tasks[i].copyWith(
      focusSeconds: _tasks[i].focusSeconds + seconds,
    );
    _append(_tasks[i].ideaId, EventTypes.timerStopped,
        microTaskId: taskId, payload: {'seconds': seconds});
    notifyListeners();
  }

  // ---- re-tasking (spec §7): blocked or proactive "break this down" ----
  Future<void> retask(String taskId, {String reason = ''}) async {
    final i = _indexOf(taskId);
    final parent = _tasks[i];
    final resp = await coordinator.plan(
      goal: parent.title,
      priorAnswers: reason.isEmpty ? 'none' : reason,
      context: PlanContext.retask,
    );
    // The re-tasking prompt instructs a plan, never a clarification. If the
    // model clarifies anyway, leave the parent untouched (safe no-op) rather
    // than corrupting state; the user can retry from the unchanged task.
    if (resp is! PlanResponse) return;
    _tasks[i] = parent.copyWith(state: TaskState.reTasked);
    _append(parent.ideaId, EventTypes.taskRetasked,
        microTaskId: taskId, payload: {'children': resp.tasks.length});
    final base = _maxOrder(parent.ideaId);
    for (final pt in resp.tasks) {
      _tasks.add(_materialize(parent.ideaId, parent.id, pt, baseOrder: base));
    }
    _recomputeIdeaStatus(parent.ideaId);
    notifyListeners();
  }

  // ---- internals ----
  int _indexOf(String taskId) {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i == -1) throw StateError('no task $taskId');
    return i;
  }

  int _maxOrder(String ideaId) => _tasks
      .where((t) => t.ideaId == ideaId)
      .fold<int>(0, (m, t) => t.orderIndex > m ? t.orderIndex : m);

  bool _transition(String id, TaskState to, String eventType,
      {Map<String, Object?> payload = const {}}) {
    final i = _indexOf(id);
    final result = applyTransition(_tasks[i], to);
    if (result is TransitionDenied) return false;
    final from = _tasks[i].state;
    _tasks[i] = (result as TransitionOk).task;
    _append(_tasks[i].ideaId, eventType,
        microTaskId: id, fromState: from, toState: to, payload: payload);
    notifyListeners();
    return true;
  }

  void _recomputeIdeaStatus(String ideaId) {
    final i = _ideas.indexWhere((x) => x.id == ideaId);
    if (i == -1) return;
    final leaves = _tasks
        .where((t) => t.ideaId == ideaId && t.state != TaskState.reTasked);
    if (leaves.isEmpty) return;
    final IdeaStatus status;
    if (leaves.every((t) => t.state == TaskState.done)) {
      status = IdeaStatus.done;
    } else if (leaves.any((t) => t.state == TaskState.blocked)) {
      status = IdeaStatus.stalled;
    } else {
      status = IdeaStatus.active;
    }
    final old = _ideas[i];
    _ideas[i] = Idea(
      id: old.id,
      title: old.title,
      rawInput: old.rawInput,
      type: old.type,
      status: status,
      planVersion: old.planVersion,
      createdAt: old.createdAt,
    );
  }

  MicroTask _materialize(String ideaId, String? parentId, PlannedTask pt,
      {int baseOrder = 0}) {
    return MicroTask(
      id: _newId(),
      ideaId: ideaId,
      parentTaskId: parentId,
      title: pt.title,
      description: pt.description,
      estMinutes: pt.estMinutes,
      orderIndex: baseOrder + pt.orderIndex,
      acceptanceCriteria: [
        for (final c in pt.acceptanceCriteria)
          AcceptanceCriterion(
            id: _newId(),
            text: c.text,
            evidenceType: _evidenceFrom(c.evidenceType),
          ),
      ],
    );
  }

  void _append(String ideaId, String type,
      {String? microTaskId,
      TaskState? fromState,
      TaskState? toState,
      Map<String, Object?> payload = const {}}) {
    store.append(EventRecord(
      id: _newId(),
      ideaId: ideaId,
      microTaskId: microTaskId,
      type: type,
      actor: type.startsWith('plan_') ? 'coordinator' : 'user',
      fromState: fromState,
      toState: toState,
      payload: payload,
      ts: _now(),
    ));
  }

  static IdeaType _typeFrom(String s) => IdeaType.values
      .firstWhere((e) => e.name == s, orElse: () => IdeaType.other);

  static EvidenceType _evidenceFrom(String s) => EvidenceType.values
      .firstWhere((e) => e.name == s, orElse: () => EvidenceType.checkbox);
}
