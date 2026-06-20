import 'planner.dart';
import 'prompts.dart';

/// Dedicated agent for transforming one TODO item into executable micro-tasks.
/// Keeps TODO chunking concerns separate from general planning/re-tasking flows.
class TodoChunkingAgent {
  const TodoChunkingAgent({
    required this.coordinator,
    this.systemPrompt = todoChunkingSystemPrompt,
  });

  final Coordinator coordinator;
  final String systemPrompt;

  Future<PlanResponse> chunkTodo(String todoItem) async {
    final response = await coordinator.plan(
      goal: todoItem,
      priorAnswers: 'none',
      systemPromptOverride: systemPrompt,
    );
    if (response is PlanResponse) return response;
    throw const CoordinatorException([
      'todo chunking agent returned clarifying questions, expected propose_plan',
    ]);
  }
}
