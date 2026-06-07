import '../models/models.dart';

/// Allowed transitions for the micro-task lifecycle (spec §2).
const Map<TaskState, Set<TaskState>> kAllowedTransitions = {
  TaskState.todo: {TaskState.inProgress, TaskState.blocked, TaskState.reTasked},
  TaskState.inProgress: {
    TaskState.awaitingApproval,
    TaskState.blocked,
    TaskState.reTasked,
  },
  TaskState.awaitingApproval: {TaskState.done, TaskState.inProgress},
  TaskState.blocked: {TaskState.reTasked, TaskState.inProgress},
  TaskState.done: {},
  TaskState.reTasked: {},
};

/// Pure check: is [to] reachable from [from] at all (ignoring guards)?
bool canTransition(TaskState from, TaskState to) =>
    kAllowedTransitions[from]?.contains(to) ?? false;

sealed class TransitionResult {
  const TransitionResult();
}

class TransitionOk extends TransitionResult {
  const TransitionOk(this.task);
  final MicroTask task;
}

class TransitionDenied extends TransitionResult {
  const TransitionDenied(this.reason);
  final String reason;
}

/// Apply a transition with guards. The only guard today: `awaiting_approval → done`
/// requires every acceptance criterion to be satisfied (spec §3).
TransitionResult applyTransition(MicroTask task, TaskState to) {
  if (!canTransition(task.state, to)) {
    return TransitionDenied('cannot go from ${task.state.name} to ${to.name}');
  }
  if (to == TaskState.done && !task.allCriteriaSatisfied) {
    return const TransitionDenied(
      'all acceptance criteria must be satisfied first',
    );
  }
  return TransitionOk(task.copyWith(state: to));
}
