import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/fake_llm_client.dart';
import 'package:stepwise/coordinator/planner.dart';
import 'package:stepwise/coordinator/todo_chunking_agent.dart';

void main() {
  test('chunkTodo uses configurable system prompt and returns a plan',
      () async {
    const customPrompt = 'CUSTOM TODO CHUNK PROMPT';
    const validPlan = '''
{
  "action": "propose_plan",
  "idea_type": "other",
  "summary": "Chunked TODO",
  "micro_tasks": [
    {
      "title": "Define the done state",
      "description": "Write what done means in one line.",
      "est_minutes": 10,
      "order_index": 1,
      "acceptance_criteria": [{"text": "Done state is written", "evidence_type": "checkbox"}]
    },
    {
      "title": "Collect required info",
      "description": "Gather all files and links needed.",
      "est_minutes": 15,
      "order_index": 2,
      "acceptance_criteria": [{"text": "Inputs are collected", "evidence_type": "checkbox"}]
    },
    {
      "title": "Execute first actionable step",
      "description": "Complete the first concrete action now.",
      "est_minutes": 20,
      "order_index": 3,
      "acceptance_criteria": [{"text": "First action completed", "evidence_type": "checkbox"}]
    }
  ]
}
''';

    final llm = FakeLlmClient(scripted: [validPlan]);
    final coordinator = Coordinator(llm);
    final agent = TodoChunkingAgent(
      coordinator: coordinator,
      systemPrompt: customPrompt,
    );

    final response = await agent.chunkTodo('file taxes');

    expect(response, isA<PlanResponse>());
    expect(llm.calls.single.system, customPrompt);
  });

  test('chunkTodo fails when model returns clarifying response', () async {
    const clarify = '''
{
  "action": "ask_clarifying",
  "questions": ["What year is this TODO for?"]
}
''';

    final llm = FakeLlmClient(scripted: [clarify]);
    final coordinator = Coordinator(llm);
    final agent = TodoChunkingAgent(coordinator: coordinator);

    await expectLater(
      () => agent.chunkTodo('file taxes'),
      throwsA(isA<CoordinatorException>()),
    );
  });
}
