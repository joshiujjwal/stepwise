import 'dart:async';

import 'package:flutter/foundation.dart';

import '../coordinator/planner.dart';
import '../coordinator/todo_chunking_agent.dart';
import '../models/models.dart';
import 'event_store.dart';
import 'persistence_store.dart';
import 'planning_job.dart';
import 'projections.dart';
import 'task_state_machine.dart';

/// Where the Idea-tab conversation is in its lifecycle (spec §11).
enum PlanningPhase { idle, thinking, clarifying, proposed, error }

/// Transient state of an in-progress idea capture conversation.
@immutable
class PlanningSession {
  const PlanningSession({
    required this.goal,
    this.context = 'none',
    this.phase = PlanningPhase.thinking,
    this.questions = const [],
    this.proposal,
    this.error,
  });

  final String goal;
  final String context;
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
      context: context,
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
/// Durability is provided by an optional [PersistenceStore] (sqflite): every
/// mutation is written through and [hydrate] restores the snapshot + event log
/// on startup, so data survives app restarts. State is still NOT reconstructed
/// by *replaying* events; that pure event-replay hydration remains a parking-lot
/// item (it would require event payloads to carry full task detail).
class AppController extends ChangeNotifier {
  AppController({
    required this.coordinator,
    this.todoChunkingAgent,
    EventStore? store,
    this.persistence,
    String Function()? idGen,
    DateTime Function()? clock,
  })  : store = store ?? InMemoryEventStore(),
        _idGen = idGen,
        _clock = clock;

  final Coordinator coordinator;
  final TodoChunkingAgent? todoChunkingAgent;
  final EventStore store;

  /// Optional durable backing store. When supplied, entity state and the event
  /// log are written through on every mutation and restored via [hydrate] on
  /// startup, so data survives app restarts. Null in hermetic tests/demos.
  final PersistenceStore? persistence;

  final String Function()? _idGen;
  final DateTime Function()? _clock;

  int _seq = 0;
  String _newId() => _idGen?.call() ?? 'id${_seq++}';
  DateTime _now() => _clock?.call() ?? DateTime.now();

  // Serializes write-through persistence so sqflite never sees concurrent
  // writes; a failed write is logged but never poisons later writes.
  Future<void> _persistQueue = Future<void>.value();

  void _enqueue(Future<void> Function(PersistenceStore store) op) {
    final store = persistence;
    if (store == null) return;
    _persistQueue = _persistQueue
        .then((_) => op(store))
        .catchError((Object e) => debugPrint('persistence write failed: $e'));
  }

  /// Await all pending write-through operations. Primarily for tests and a
  /// clean shutdown; UI code does not need to call this.
  Future<void> flushPersistence() => _persistQueue;

  /// Restore entity state and the event log from [persistence] on startup.
  /// No-op when persistence is not configured. Safe to call once before the
  /// first frame; later mutations are written through automatically.
  Future<void> hydrate() async {
    final store = persistence;
    if (store == null) return;
    final snapshot = await store.load();
    _ideas
      ..clear()
      ..addAll(snapshot.ideas);
    _tasks
      ..clear()
      ..addAll(snapshot.tasks);
    _jobs
      ..clear()
      ..addAll(snapshot.jobs);
    for (final event in snapshot.events) {
      this.store.append(event);
    }
    _advanceSeqPastRestoredIds(snapshot);
    notifyListeners();
  }

  // Generated ids look like `idN`. After hydrating restored entities we must
  // bump _seq past the highest id index so new ids never collide — including
  // [PersistedState.maxIdSeq], which also accounts for rows that were present
  // but skipped during decode (a corrupt latest write).
  void _advanceSeqPastRestoredIds(PersistedState snapshot) {
    final max = maxIdSeqOf(
      [
        for (final idea in snapshot.ideas) idea.id,
        for (final task in snapshot.tasks) ...[
          task.id,
          for (final c in task.acceptanceCriteria) c.id,
        ],
        for (final event in snapshot.events) event.id,
        for (final job in snapshot.jobs) job.id,
      ],
      floor: snapshot.maxIdSeq > _seq - 1 ? snapshot.maxIdSeq : _seq - 1,
    );
    _seq = max + 1;
  }

  final List<Idea> _ideas = [];
  final List<MicroTask> _tasks = [];
  final List<PlanningJob> _jobs = [];
  final Map<String, DateTime> _timerRunning = {};
  Timer? _timerTicker;
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

  int remainingFocusSeconds(String taskId) {
    final task = taskById(taskId);
    final started = _timerRunning[taskId];
    final elapsed = started == null ? 0 : _now().difference(started).inSeconds;
    final totalSeconds = task.estMinutes * 60;
    final remaining = totalSeconds - task.focusSeconds - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  MicroTask taskById(String id) => _tasks.firstWhere((t) => t.id == id);

  // ---- idea capture (conversational, spec §4/§11) ----
  Future<void> submitGoal(String goal, {String context = 'none'}) async {
    _session = PlanningSession(goal: goal, context: context);
    notifyListeners();
    await _runPlanner(goal, 'none', context);
  }

  /// TODO-first flow: the user writes one TODO item and the dedicated agent
  /// enhances/splits it into time-boxed executable chunks. Optional [context]
  /// tells the planner where the user is starting from (issue #9).
  Future<void> submitTodoItem(String todoItem,
      {String context = 'none'}) async {
    _session = PlanningSession(goal: todoItem, context: context);
    notifyListeners();

    final agent = todoChunkingAgent;
    if (agent == null) {
      await _runPlanner(todoItem, 'none', context);
      return;
    }

    try {
      final proposal = await agent.chunkTodo(todoItem, context: context);
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
    await _runPlanner(s.goal, answers.isEmpty ? 'none' : answers, s.context);
  }

  Future<void> _runPlanner(String goal, String answers, String context) async {
    try {
      final resp = await coordinator.plan(
          goal: goal, priorAnswers: answers, startingContext: context);
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
    _enqueue((p) => p.upsertIdea(idea));
    _append(idea.id, EventTypes.ideaCreated);
    _append(idea.id, EventTypes.planConfirmed,
        payload: {'taskCount': proposal.tasks.length});
    for (final pt in proposal.tasks) {
      final task = _materialize(idea.id, null, pt);
      _tasks.add(task);
      _enqueue((p) => p.upsertTask(task));
    }
    _session = null;
    notifyListeners();
    return idea;
  }

  void discardPlan() {
    _session = null;
    notifyListeners();
  }

  // ---- background planning jobs (spec §11, background variant) ----
  //
  // Unlike the interactive [_session] flow, a job runs the coordinator off the
  // UI thread and waits in a review inbox until the user submits or discards it.
  // On-device Gemma is single-threaded, so queued jobs run one at a time.

  /// All background jobs, newest last.
  List<PlanningJob> get jobs => List.unmodifiable(_jobs);

  /// Jobs whose plan is ready to review and submit.
  List<PlanningJob> get readyJobs =>
      _jobs.where((j) => j.isReady).toList(growable: false);

  PlanningJob? jobById(String id) {
    final i = _jobIndex(id);
    return i == -1 ? null : _jobs[i];
  }

  /// Serializes planner runs so on-device Gemma never sees concurrent requests.
  Future<void> _jobQueue = Future<void>.value();

  /// Await all queued/in-flight background planning. For tests and a clean
  /// shutdown; UI code observes status changes via [notifyListeners] instead.
  Future<void> flushPlanningJobs() => _jobQueue;

  /// Kick off decomposition of [goal] in the background. Returns the new job id
  /// immediately; the plan becomes available via [jobById]/[readyJobs] once the
  /// coordinator finishes.
  String startPlanningJob(String goal, {String context = 'none'}) {
    final id = _newId();
    final job = PlanningJob(
      id: id,
      goal: goal,
      status: PlanningJobStatus.thinking,
      createdAt: _now(),
      context: context,
    );
    _jobs.add(job);
    _enqueue((p) => p.upsertJob(job));
    notifyListeners();
    _scheduleJob(id, goal, 'none', context);
    return id;
  }

  /// Answer a clarifying job; re-runs planning in the background with [answers].
  void answerJob(String id, String answers) {
    final i = _jobIndex(id);
    if (i == -1) return;
    final goal = _jobs[i].goal;
    final context = _jobs[i].context;
    _updateJob(
        id,
        (j) => j
            .copyWith(status: PlanningJobStatus.thinking, questions: const []));
    _scheduleJob(
        id, goal, answers.trim().isEmpty ? 'none' : answers.trim(), context);
  }

  /// Replace a ready job's plan with an edited one (edit-before-submit).
  void updateJobProposal(String id, PlanResponse proposal) {
    _updateJob(id,
        (j) => j.copyWith(status: PlanningJobStatus.ready, proposal: proposal));
  }

  /// Persist a ready job's plan as an idea + micro-tasks, then remove the job.
  Idea submitJob(String id) {
    final i = _jobIndex(id);
    if (i == -1) throw StateError('no job $id');
    final proposal = _jobs[i].proposal;
    if (proposal == null) {
      throw StateError('job $id has no proposal to submit');
    }
    final goal = _jobs[i].goal;
    final idea = Idea(
      id: _newId(),
      title: goal,
      rawInput: goal,
      type: _typeFrom(proposal.ideaType),
      status: IdeaStatus.active,
      createdAt: _now(),
    );
    _ideas.add(idea);
    _enqueue((p) => p.upsertIdea(idea));
    _append(idea.id, EventTypes.ideaCreated);
    _append(idea.id, EventTypes.planConfirmed,
        payload: {'taskCount': proposal.tasks.length});
    for (final pt in proposal.tasks) {
      final task = _materialize(idea.id, null, pt);
      _tasks.add(task);
      _enqueue((p) => p.upsertTask(task));
    }
    _jobs.removeAt(i);
    _enqueue((p) => p.deleteJob(id));
    notifyListeners();
    return idea;
  }

  /// Drop a job without persisting anything.
  void discardJob(String id) {
    final i = _jobIndex(id);
    if (i == -1) return;
    _jobs.removeAt(i);
    _enqueue((p) => p.deleteJob(id));
    notifyListeners();
  }

  int _jobIndex(String id) => _jobs.indexWhere((j) => j.id == id);

  void _updateJob(String id, PlanningJob Function(PlanningJob) transform) {
    final i = _jobIndex(id);
    if (i == -1) return;
    _jobs[i] = transform(_jobs[i]);
    _enqueue((p) => p.upsertJob(_jobs[i]));
    notifyListeners();
  }

  void _scheduleJob(String id, String goal, String answers, String context) {
    _jobQueue = _jobQueue.then((_) => _runJob(id, goal, answers, context));
  }

  Future<void> _runJob(
      String id, String goal, String answers, String context) async {
    // The job may have been discarded while queued behind another run.
    if (_jobIndex(id) == -1) return;
    try {
      final resp = await coordinator.plan(
          goal: goal, priorAnswers: answers, startingContext: context);
      _updateJob(
        id,
        (j) => switch (resp) {
          ClarifyResponse(:final questions) => j.copyWith(
              status: PlanningJobStatus.clarifying, questions: questions),
          PlanResponse() =>
            j.copyWith(status: PlanningJobStatus.ready, proposal: resp),
        },
      );
    } on CoordinatorException catch (e) {
      _updateJob(
          id,
          (j) => j.copyWith(
              status: PlanningJobStatus.error, error: e.errors.join('; ')));
    } catch (e) {
      _updateJob(
          id,
          (j) =>
              j.copyWith(status: PlanningJobStatus.error, error: e.toString()));
    }
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

  bool unstuckTask(String id) {
    final ok = _transition(id, TaskState.inProgress, EventTypes.taskUnstuck);
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
    _enqueue((p) => p.upsertTask(_tasks[i]));
    _append(t.ideaId, EventTypes.criterionSatisfied,
        microTaskId: taskId, payload: {'criterionId': criterionId});
    notifyListeners();
  }

  void scheduleTask(String taskId, DateTime start) {
    final i = _indexOf(taskId);
    _tasks[i] = _tasks[i].copyWith(scheduledStart: start);
    _enqueue((p) => p.upsertTask(_tasks[i]));
    _append(_tasks[i].ideaId, EventTypes.taskScheduled,
        microTaskId: taskId, payload: {'start': start.toIso8601String()});
    notifyListeners();
  }

  // ---- focus timer (spec §5) ----
  void startTimer(String taskId) {
    if (_timerRunning.containsKey(taskId)) return;
    _timerRunning[taskId] = _now();
    _ensureTimerTicker();
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
    _enqueue((p) => p.upsertTask(_tasks[i]));
    _append(_tasks[i].ideaId, EventTypes.timerStopped,
        microTaskId: taskId, payload: {'seconds': seconds});
    if (_timerRunning.isEmpty) _stopTimerTicker();
    notifyListeners();
  }

  // ---- re-tasking (spec §7): blocked task decomposition ----
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
    _enqueue((p) => p.upsertTask(_tasks[i]));
    _append(parent.ideaId, EventTypes.taskRetasked,
        microTaskId: taskId, payload: {'children': resp.tasks.length});
    final base = _maxOrder(parent.ideaId);
    for (final pt in resp.tasks) {
      final child = _materialize(parent.ideaId, parent.id, pt, baseOrder: base);
      _tasks.add(child);
      _enqueue((p) => p.upsertTask(child));
    }
    _recomputeIdeaStatus(parent.ideaId);
    notifyListeners();
  }

  // ---- internals ----
  void _ensureTimerTicker() {
    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerRunning.isEmpty) {
        _stopTimerTicker();
        return;
      }
      notifyListeners();
    });
  }

  void _stopTimerTicker() {
    _timerTicker?.cancel();
    _timerTicker = null;
  }

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
    _enqueue((p) => p.upsertTask(_tasks[i]));
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
    _enqueue((p) => p.upsertIdea(_ideas[i]));
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
    final record = EventRecord(
      id: _newId(),
      ideaId: ideaId,
      microTaskId: microTaskId,
      type: type,
      actor: type.startsWith('plan_') ? 'coordinator' : 'user',
      fromState: fromState,
      toState: toState,
      payload: payload,
      ts: _now(),
    );
    store.append(record);
    _enqueue((p) => p.appendEvent(record));
  }

  static IdeaType _typeFrom(String s) => IdeaType.values
      .firstWhere((e) => e.name == s, orElse: () => IdeaType.other);

  static EvidenceType _evidenceFrom(String s) => EvidenceType.values
      .firstWhere((e) => e.name == s, orElse: () => EvidenceType.checkbox);

  @override
  void dispose() {
    _stopTimerTicker();
    super.dispose();
  }
}
