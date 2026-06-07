import 'dart:convert';

// A deterministic, offline planner. Powers "demo mode" (the app is fully usable
// with no model downloaded) and makes Coordinator tests hermetic. Produces valid
// PlannerResponse JSON per tool/coordinator/plan.schema.json.

class DemoPlanner {
  const DemoPlanner();

  String guessType(String goal) {
    final g = goal.toLowerCase();
    bool has(List<String> ws) => ws.any(g.contains);
    if (has(['tax', 'irs', 'return', 'w-2', '1099'])) return 'tax';
    if (has(['trip', 'travel', 'flight', 'vacation', 'hotel'])) return 'trip';
    if (has(['buy', 'call', 'book', 'pick up', 'errand', 'appointment'])) {
      return 'errand';
    }
    if (has(['form', 'apply', 'renew', 'register', 'account', 'bill'])) {
      return 'admin';
    }
    if (has(['build', 'launch', 'write', 'plan', 'project', 'app'])) {
      return 'project';
    }
    return 'other';
  }

  Map<String, Object?> _task(
    String title,
    String description,
    int est,
    int order,
    String criterion, [
    String evidence = 'checkbox',
  ]) {
    return {
      'title': title,
      'description': description,
      'est_minutes': est,
      'order_index': order,
      'acceptance_criteria': [
        {'text': criterion, 'evidence_type': evidence},
      ],
    };
  }

  String planJson(String goal) {
    final tasks = [
      _task(
          'Write down the outcome you want',
          'Note in one line what "done" looks like for: $goal.',
          15,
          1,
          'You wrote a one-line definition of done'),
      _task(
          'Collect what you need to start',
          'Gather the documents, links, or tools this will require.',
          20,
          2,
          'Everything you need is in one place'),
      _task(
          'Do the first concrete step',
          'Take the very first small action toward the goal.',
          30,
          3,
          'The first step is finished'),
      _task(
          'Do the main part of the work',
          'Complete the core of the task in one focused sitting.',
          45,
          4,
          'The main work is finished'),
      _task(
          'Check the result and finish up',
          'Review what you did and confirm it is complete.',
          15,
          5,
          'Reviewed and confirmed complete'),
    ];
    return jsonEncode({
      'action': 'propose_plan',
      'idea_type': guessType(goal),
      'summary': 'A simple starting plan for: $goal',
      'micro_tasks': tasks,
    });
  }

  String clarifyJson() {
    return jsonEncode({
      'action': 'ask_clarifying',
      'questions': ['In one line, what would make this feel done?'],
    });
  }

  String retaskJson(String parentTitle) {
    final tasks = [
      _task(
          'Break "$parentTitle" into a first move',
          'Identify the smallest possible first action.',
          10,
          1,
          'First small action identified'),
      _task(
          'Do that first small action now',
          'Complete just that one small action.',
          15,
          2,
          'The small action is done'),
      _task(
          'Finish the rest of the original step',
          'Complete what remains of the original task.',
          20,
          3,
          'The original step is complete'),
    ];
    return jsonEncode({
      'action': 'propose_plan',
      'idea_type': 'other',
      'summary': 'Smaller steps for: $parentTitle',
      'micro_tasks': tasks,
    });
  }
}
