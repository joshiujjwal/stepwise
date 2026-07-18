import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/prompts.dart';

void main() {
  test('Gemma-style malformed JSON triggers one repair with bounded prompt',
      () async {
    final largeDetail = 'x' * 5000;
    final gemmaLikeMalformed = '''
```json
{
  "type": "tax",
  "plan": [
    {
      "action": "Gather tax documents",
      "description": "$largeDetail",
      "acceptance_criteria": ["All documents gathered"],
      "order_index": 1
    }
  ]
}
```
''';

    final validPlan = '''
{
  "action": "propose_plan",
  "idea_type": "tax",
  "summary": "A valid repaired plan",
  "micro_tasks": [
    {
      "title": "Gather tax documents",
      "description": "Collect W-2s and 1099s into one folder.",
      "est_minutes": 20,
      "order_index": 1,
      "acceptance_criteria": [{"text": "All tax forms in one folder", "evidence_type": "checkbox"}]
    },
    {
      "title": "Create filing checklist",
      "description": "Write a short checklist for filing steps.",
      "est_minutes": 15,
      "order_index": 2,
      "acceptance_criteria": [{"text": "Checklist has at least three steps", "evidence_type": "note"}]
    },
    {
      "title": "Start filing draft",
      "description": "Enter documents into the filing tool to create a draft return.",
      "est_minutes": 30,
      "order_index": 3,
      "acceptance_criteria": [{"text": "Draft return is saved", "evidence_type": "checkbox"}]
    }
  ]
}
''';

    final llm = FakeLlmClient(scripted: [gemmaLikeMalformed, validPlan]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'file my taxes');

    expect(response, isA<PlanResponse>());
    expect(llm.calls.length, 2);
    expect(llm.calls[1].system, repairSystemPrompt);
    expect(llm.calls[1].user, contains('Validation errors:'));
    expect(llm.calls[1].user, contains('[truncated]'));
    expect(llm.calls[1].user.length, lessThan(2600));
  });

  test(
      'parses valid JSON object even when wrapped in chatter and braces in string',
      () async {
    final wrappedResponse = '''
Sure — here is the plan:
{
  "action": "propose_plan",
  "idea_type": "project",
  "summary": "A direct plan",
  "micro_tasks": [
    {
      "title": "Define done state",
      "description": "Write one sentence that starts with {done means ...",
      "est_minutes": 10,
      "order_index": 1,
      "acceptance_criteria": [{"text": "One sentence is written", "evidence_type": "checkbox"}]
    },
    {
      "title": "Collect required inputs",
      "description": "Gather the docs and links you need.",
      "est_minutes": 15,
      "order_index": 2,
      "acceptance_criteria": [{"text": "All required inputs listed", "evidence_type": "note"}]
    },
    {
      "title": "Do first concrete step",
      "description": "Complete the first actionable step now.",
      "est_minutes": 20,
      "order_index": 3,
      "acceptance_criteria": [{"text": "First step completed", "evidence_type": "checkbox"}]
    }
  ]
}
Thanks.
''';

    final llm = FakeLlmClient(scripted: [wrappedResponse]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'ship onboarding flow');

    expect(response, isA<PlanResponse>());
    expect(llm.calls.length, 1);
  });

  test('parses a quoted JSON-string response without repair', () async {
    const quotedJsonString =
        '"{\\"action\\":\\"propose_plan\\",\\"idea_type\\":\\"admin\\",\\"summary\\":\\"Quick plan\\",\\"micro_tasks\\":[{\\"title\\":\\"Collect account details\\",\\"description\\":\\"Gather account numbers and IDs in one note.\\",\\"est_minutes\\":10,\\"order_index\\":1,\\"acceptance_criteria\\":[{\\"text\\":\\"Account details listed\\",\\"evidence_type\\":\\"checkbox\\"}]},{\\"title\\":\\"Draft the request\\",\\"description\\":\\"Write the request message in one draft.\\",\\"est_minutes\\":15,\\"order_index\\":2,\\"acceptance_criteria\\":[{\\"text\\":\\"Draft completed\\",\\"evidence_type\\":\\"note\\"}]},{\\"title\\":\\"Submit and log confirmation\\",\\"description\\":\\"Send the request and save confirmation info.\\",\\"est_minutes\\":20,\\"order_index\\":3,\\"acceptance_criteria\\":[{\\"text\\":\\"Confirmation recorded\\",\\"evidence_type\\":\\"checkbox\\"}]}]}"';

    final llm = FakeLlmClient(scripted: [quotedJsonString]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'request admin update');

    expect(response, isA<PlanResponse>());
    expect(llm.calls.length, 1);
  });

  test('normalizes legacy type+plan response without repair call', () async {
    const legacyShape = '''
{
  "type": "tax",
  "plan": [
    {
      "action": "Gather tax documents",
      "description": "Collect all relevant tax forms.",
      "acceptance_criteria": [
        "Checkbox: All W-2s are collected.",
        "Checkbox: All 1099s are collected."
      ],
      "order_index": 1
    },
    {
      "action": "Organize documents by type",
      "description": "Sort documents into categories.",
      "acceptance_criteria": [
        "Checkbox: Forms are sorted."
      ],
      "order_index": 2
    },
    {
      "action": "Start filing draft",
      "description": "Enter the organized data into your filing tool.",
      "acceptance_criteria": [
        "Checkbox: Draft return is created."
      ],
      "order_index": 3
    }
  ]
}
''';

    final llm = FakeLlmClient(scripted: [legacyShape]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'file 2025 taxes');
    final plan = response as PlanResponse;

    expect(plan.ideaType, 'tax');
    expect(plan.tasks.length, 3);
    expect(plan.tasks.first.title, 'Gather tax documents');
    expect(plan.tasks.first.acceptanceCriteria.first.text,
        'All W-2s are collected.');
    expect(llm.calls.length, 1);
  });

  test('parses fenced JSON with surrounding text on repair response', () async {
    const fencedResponse = '''
Here is the repaired plan:
```json
{
  "action": "propose_plan",
  "idea_type": "project",
  "summary": "Build a capsule wardrobe for men with versatile pieces.",
  "micro_tasks": [
    {
      "title": "Brainstorm core pieces",
      "description": "List essential clothing items for the wardrobe.",
      "est_minutes": 20,
      "order_index": 1,
      "acceptance_criteria": [
        {"text": "List of essential items created", "evidence_type": "checkbox"}
      ]
    },
    {
      "title": "Pick matching items",
      "description": "Choose pieces that can be mixed and matched.",
      "est_minutes": 25,
      "order_index": 2,
      "acceptance_criteria": [
        {"text": "Matching items selected", "evidence_type": "checkbox"}
      ]
    },
    {
      "title": "Write the shopping list",
      "description": "Turn the selected items into a short shopping list.",
      "est_minutes": 15,
      "order_index": 3,
      "acceptance_criteria": [
        {"text": "Shopping list is written", "evidence_type": "note"}
      ]
    }
  ]
}
```
Thanks!
''';

    final llm = FakeLlmClient(scripted: [fencedResponse]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'build a capsule wardrobe');

    expect(response, isA<PlanResponse>());
    expect(llm.calls.length, 1);
  });

  test(
      'normalizes propose_plan criteria missing evidence_type without repair call',
      () async {
    const missingEvidence = '''
{
  "action": "propose_plan",
  "idea_type": "project",
  "summary": "Build a capsule wardrobe with versatile pieces.",
  "micro_tasks": [
    {
      "title": "Brainstorm wardrobe staples",
      "description": "List essential clothing items.",
      "est_minutes": 15,
      "order_index": 5,
      "acceptance_criteria": [
        {"text": "List of items created"},
        {"text": "Items can be mixed and matched"}
      ]
    },
    {
      "title": "Audit current closet",
      "description": "Check what you already own.",
      "est_minutes": 20,
      "order_index": 2,
      "acceptance_criteria": [
        {"text": "Ownable items identified"}
      ]
    },
    {
      "title": "Create final shopping list",
      "description": "Capture missing pieces in one list.",
      "est_minutes": 10,
      "order_index": 9,
      "acceptance_criteria": [
        {"text": "Final list is written"}
      ]
    }
  ]
}
''';

    final llm = FakeLlmClient(scripted: [missingEvidence]);
    final coordinator = Coordinator(llm);
    final response = await coordinator.plan(goal: 'build a capsule wardrobe');
    final plan = response as PlanResponse;

    expect(llm.calls.length, 1);
    expect(plan.tasks, hasLength(3));
    expect(
      plan.tasks
          .expand((t) => t.acceptanceCriteria)
          .every((c) => c.evidenceType == 'checkbox'),
      isTrue,
    );
    expect(plan.tasks.map((t) => t.orderIndex).toList(), [1, 2, 3]);
  });

  test('returns JSON-shaped error envelope when unrecoverable', () async {
    const invalid1 = 'not json at all';
    const invalid2 = 'also not json';

    final llm = FakeLlmClient(scripted: [invalid1, invalid2]);
    final coordinator = Coordinator(llm);

    try {
      await coordinator.plan(goal: 'irrecoverable response');
      fail('Expected CoordinatorException');
    } on CoordinatorException catch (e) {
      expect(e.errors, hasLength(1));
      final envelope = jsonDecode(e.errors.first) as Map<String, dynamic>;
      expect(envelope['action'], 'error');
      expect(envelope['error_type'], 'planner_response_invalid');
      expect(envelope['errors'], isA<List<dynamic>>());
    }
  });

  // Real on-device Gemma 3n E2B output: no top-level "action", a "tasks" list
  // instead of "micro_tasks", and each task rendered in the acceptance-criterion
  // shape ({text, evidence_type}). Should coerce to a valid plan without repair.
  test('normalizes actionless "tasks" list with criterion-shaped items',
      () async {
    const gemmaShape = '{"idea_type": "trip", "tasks": ['
        '{"text": "Book flights", "evidence_type": "checkbox"}, '
        '{"text": "Reserve hotel", "evidence_type": "checkbox"}, '
        '{"text": "Pack essentials", "evidence_type": "checkbox"}]}';

    final llm = FakeLlmClient(scripted: [gemmaShape]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'plan a weekend trip');
    final plan = response as PlanResponse;

    expect(llm.calls.length, 1, reason: 'should not need a repair round');
    expect(plan.ideaType, 'trip');
    expect(plan.tasks.map((t) => t.title).toList(),
        ['Book flights', 'Reserve hotel', 'Pack essentials']);
    expect(plan.tasks.map((t) => t.orderIndex).toList(), [1, 2, 3]);
    for (final t in plan.tasks) {
      expect(t.acceptanceCriteria, isNotEmpty);
    }
  });

  // Real on-device Gemma 3n E2B output: no "action", a "tasks" list, and each
  // task nested under a "task" key with the title missing (only a description).
  test('normalizes actionless "tasks" list with nested "task" objects',
      () async {
    const gemmaShape = '{"idea_type": "errand", "tasks": ['
        '{"order_index": 1, "task": {'
        '"description": "Make a grocery list based on your needs.", '
        '"acceptance_criteria": [{"text": "List includes all items", "evidence_type": "checkbox"}], '
        '"est_minutes": 20}}, '
        '{"order_index": 2, "task": {'
        '"description": "Check your pantry for existing supplies.", '
        '"acceptance_criteria": [{"text": "Pantry checked", "evidence_type": "checkbox"}], '
        '"est_minutes": 10}}, '
        '{"order_index": 3, "task": {'
        '"description": "Drive to the store and buy the items.", '
        '"acceptance_criteria": [{"text": "All items purchased", "evidence_type": "checkbox"}], '
        '"est_minutes": 45}}]}';

    final llm = FakeLlmClient(scripted: [gemmaShape]);
    final coordinator = Coordinator(llm);

    final response = await coordinator.plan(goal: 'buy groceries');
    final plan = response as PlanResponse;

    expect(llm.calls.length, 1, reason: 'should not need a repair round');
    expect(plan.ideaType, 'errand');
    expect(plan.tasks.length, 3);
    expect(
        plan.tasks[0].description, 'Make a grocery list based on your needs.');
    expect(plan.tasks[0].estMinutes, 20);
    expect(plan.tasks[0].title.trim(), isNotEmpty);
    expect(
        plan.tasks[0].acceptanceCriteria.first.text, 'List includes all items');
    expect(plan.tasks.map((t) => t.orderIndex).toList(), [1, 2, 3]);
  });
}
