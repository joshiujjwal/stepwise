import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/models/models.dart';
import 'package:stepwise/state/event_store.dart';

EventRecord _ev(String ideaId, String type) => EventRecord(
      id: '$ideaId-$type',
      ideaId: ideaId,
      type: type,
      actor: 'user',
      ts: DateTime(2026, 6, 6),
    );

void main() {
  test('append preserves order and exposes an unmodifiable view', () {
    final store = InMemoryEventStore();
    store.append(_ev('i1', EventTypes.ideaCreated));
    store.append(_ev('i1', EventTypes.planConfirmed));
    expect(store.events.map((e) => e.type),
        [EventTypes.ideaCreated, EventTypes.planConfirmed]);
    expect(() => store.events.add(_ev('x', 'y')), throwsUnsupportedError);
  });

  test('eventsForIdea filters by idea', () {
    final store = InMemoryEventStore();
    store.append(_ev('i1', EventTypes.ideaCreated));
    store.append(_ev('i2', EventTypes.ideaCreated));
    store.append(_ev('i1', EventTypes.taskApproved));
    expect(store.eventsForIdea('i1').length, 2);
    expect(store.eventsForIdea('i2').length, 1);
  });
}
