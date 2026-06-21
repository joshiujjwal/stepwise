import '../models/models.dart';

/// Canonical event type names. Using constants avoids stringly-typed bugs and
/// keeps the projection layer in sync with the controller.
abstract final class EventTypes {
  static const ideaCreated = 'idea_created';
  static const planProposed = 'plan_proposed';
  static const planConfirmed = 'plan_confirmed';
  static const taskStarted = 'task_started';
  static const taskSubmitted = 'task_submitted';
  static const taskApproved = 'task_approved';
  static const taskRejected = 'task_rejected';
  static const taskBlocked = 'task_blocked';
  static const taskUnstuck = 'task_unstuck';
  static const taskRetasked = 'task_retasked';
  static const criterionSatisfied = 'criterion_satisfied';
  static const estimateOverridden = 'estimate_overridden';
  static const taskScheduled = 'task_scheduled';
  static const timerStarted = 'timer_started';
  static const timerPaused = 'timer_paused';
  static const timerResumed = 'timer_resumed';
  static const timerStopped = 'timer_stopped';
}

/// Append-only log of domain events. The source of truth for trends/history
/// (spec §1). The in-memory implementation runs in-app today; a sqflite
/// write-through adapter is a device-runtime concern (parking lot).
abstract interface class EventStore {
  void append(EventRecord event);

  /// Events in chronological (append) order.
  List<EventRecord> get events;

  /// Events for a single idea, chronological.
  List<EventRecord> eventsForIdea(String ideaId);
}

class InMemoryEventStore implements EventStore {
  final List<EventRecord> _events = [];

  @override
  void append(EventRecord event) => _events.add(event);

  @override
  List<EventRecord> get events => List.unmodifiable(_events);

  @override
  List<EventRecord> eventsForIdea(String ideaId) =>
      _events.where((e) => e.ideaId == ideaId).toList(growable: false);
}
