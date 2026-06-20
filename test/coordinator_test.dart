import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/prompts.dart';

void main() {
  test('Gemma-style malformed JSON triggers one repair with bounded prompt', () async {
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

  test('parses valid JSON object even when wrapped in chatter and braces in string', () async {
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
}
