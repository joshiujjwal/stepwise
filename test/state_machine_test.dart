import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/task_state_machine.dart';

MicroTask _task(TaskState state, {bool satisfied = false}) {
  return MicroTask(
    id: 't',
    ideaId: 'i',
    title: 'Do the thing',
    description: 'd',
    estMinutes: 15,
    orderIndex: 1,
    state: state,
    acceptanceCriteria: [
      AcceptanceCriterion(id: 'a', text: 'a criterion', satisfied: satisfied),
    ],
  );
}

void main() {
  test('allows todo -> in_progress', () {
    expect(canTransition(TaskState.todo, TaskState.inProgress), isTrue);
  });

  test('disallows todo -> done directly', () {
    expect(canTransition(TaskState.todo, TaskState.done), isFalse);
  });

  test('done gate requires all criteria satisfied', () {
    final denied =
        applyTransition(_task(TaskState.awaitingApproval), TaskState.done);
    expect(denied, isA<TransitionDenied>());

    final ok = applyTransition(
      _task(TaskState.awaitingApproval, satisfied: true),
      TaskState.done,
    );
    expect(ok, isA<TransitionOk>());
    expect((ok as TransitionOk).task.state, TaskState.done);
  });

  test('blocked can be re-tasked', () {
    expect(canTransition(TaskState.blocked, TaskState.reTasked), isTrue);
  });
}
