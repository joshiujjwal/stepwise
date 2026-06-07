import 'dart:convert';

import 'prompts.dart';

// PlannerResponse parsing + validation + the repair loop.
// Validation rules mirror tool/coordinator/validate_plan.py (kept in lockstep;
// the fixtures under tool/coordinator/fixtures/ are the regression guard).

const Set<String> kEvidenceTypes = {'checkbox', 'note', 'url', 'file'};
const Set<String> kIdeaTypes = {
  'tax',
  'trip',
  'errand',
  'admin',
  'project',
  'other',
};

/// Parsed planner output: either a clarifying turn or a proposed plan.
sealed class PlannerResponse {
  const PlannerResponse();
}

class ClarifyResponse extends PlannerResponse {
  const ClarifyResponse(this.questions);
  final List<String> questions;
}

class PlanResponse extends PlannerResponse {
  const PlanResponse({
    required this.ideaType,
    required this.tasks,
    this.summary,
  });
  final String ideaType;
  final String? summary;
  final List<PlannedTask> tasks;
}

class PlannedTask {
  const PlannedTask({
    required this.title,
    required this.description,
    required this.estMinutes,
    required this.orderIndex,
    required this.acceptanceCriteria,
  });
  final String title;
  final String description;
  final int estMinutes;
  final int orderIndex;
  final List<PlannedCriterion> acceptanceCriteria;
}

class PlannedCriterion {
  const PlannedCriterion({required this.text, required this.evidenceType});
  final String text;
  final String evidenceType;
}

enum PlanContext { plan, retask }

/// Validate a decoded JSON object. Returns human-readable errors; empty == valid.
/// Mirrors validate_plan.py.
List<String> validatePlannerJson(
  Map<String, dynamic> obj, {
  PlanContext context = PlanContext.plan,
}) {
  final errors = <String>[];
  final action = obj['action'];
  if (action == 'ask_clarifying') {
    _validateClarify(obj, errors);
  } else if (action == 'propose_plan') {
    _validatePlan(obj, context, errors);
  } else {
    errors.add('\$.action: must be "ask_clarifying" or "propose_plan", got $action');
  }
  return errors;
}

void _validateClarify(Map<String, dynamic> obj, List<String> errors) {
  final qs = obj['questions'];
  if (qs is! List || qs.isEmpty || qs.length > 2) {
    errors.add('\$.questions: must be a list of 1-2 questions');
    return;
  }
  for (var i = 0; i < qs.length; i++) {
    final q = qs[i];
    if (q is! String || q.trim().length < 5 || q.trim().length > 160) {
      errors.add('\$.questions[$i]: must be a 5-160 char string');
    }
  }
}

void _validatePlan(
  Map<String, dynamic> obj,
  PlanContext context,
  List<String> errors,
) {
  if (!kIdeaTypes.contains(obj['idea_type'])) {
    errors.add('\$.idea_type: must be one of $kIdeaTypes');
  }
  final tasks = obj['micro_tasks'];
  if (tasks is! List) {
    errors.add('\$.micro_tasks: must be a list');
    return;
  }
  final n = tasks.length;
  final lo = context == PlanContext.retask ? 2 : 3;
  final hi = context == PlanContext.retask ? 8 : 15;
  if (n < lo || n > hi) {
    errors.add('\$.micro_tasks: expected $lo-$hi tasks, got $n');
  }
  final orders = <int>[];
  for (var i = 0; i < tasks.length; i++) {
    final t = tasks[i];
    final p = '\$.micro_tasks[$i]';
    if (t is! Map) {
      errors.add('$p: must be an object');
      continue;
    }
    final title = t['title'];
    if (title is! String || title.trim().length < 6 || title.trim().length > 80) {
      errors.add('$p.title: must be a 6-80 char string');
    }
    final desc = t['description'];
    if (desc is! String || desc.trim().isEmpty) {
      errors.add('$p.description: must be a non-empty string');
    }
    final em = t['est_minutes'];
    if (em is! int || em < 5 || em > 60 || em % 5 != 0) {
      errors.add('$p.est_minutes: must be an integer 5-60, multiple of 5');
    }
    final oi = t['order_index'];
    if (oi is! int || oi < 1) {
      errors.add('$p.order_index: must be an integer >= 1');
    } else {
      orders.add(oi);
    }
    _validateCriteria(t['acceptance_criteria'], p, errors);
  }
  if (orders.isNotEmpty) {
    final sorted = [...orders]..sort();
    final expected = [for (var k = 1; k <= tasks.length; k++) k];
    if (!_listEquals(sorted, expected)) {
      errors.add(
        '\$.micro_tasks[].order_index: must be a permutation of 1..${tasks.length}',
      );
    }
  }
}

void _validateCriteria(Object? acs, String p, List<String> errors) {
  if (acs is! List || acs.isEmpty || acs.length > 4) {
    errors.add('$p.acceptance_criteria: must be a list of 1-4 criteria');
    return;
  }
  for (var j = 0; j < acs.length; j++) {
    final cp = '$p.acceptance_criteria[$j]';
    final ac = acs[j];
    if (ac is! Map) {
      errors.add('$cp: must be an object');
      continue;
    }
    final text = ac['text'];
    if (text is! String || text.trim().length < 4 || text.trim().length > 160) {
      errors.add('$cp.text: must be a 4-160 char string');
    }
    if (!kEvidenceTypes.contains(ac['evidence_type'])) {
      errors.add('$cp.evidence_type: must be one of $kEvidenceTypes');
    }
  }
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Build a typed [PlannerResponse] from already-valid JSON.
/// Throws [FormatException] if validation fails - callers should use [Coordinator]
/// (which validates + repairs) or call [validatePlannerJson] first.
PlannerResponse parsePlannerResponse(Map<String, dynamic> obj) {
  final errors = validatePlannerJson(obj);
  if (errors.isNotEmpty) {
    throw FormatException('invalid planner response: ${errors.first}');
  }
  if (obj['action'] == 'ask_clarifying') {
    return ClarifyResponse([
      for (final q in (obj['questions'] as List)) q as String,
    ]);
  }
  final tasks = <PlannedTask>[];
  for (final t in (obj['micro_tasks'] as List)) {
    final m = t as Map;
    tasks.add(
      PlannedTask(
        title: m['title'] as String,
        description: m['description'] as String,
        estMinutes: m['est_minutes'] as int,
        orderIndex: m['order_index'] as int,
        acceptanceCriteria: [
          for (final c in (m['acceptance_criteria'] as List))
            PlannedCriterion(
              text: (c as Map)['text'] as String,
              evidenceType: c['evidence_type'] as String,
            ),
        ],
      ),
    );
  }
  return PlanResponse(
    ideaType: obj['idea_type'] as String,
    summary: obj['summary'] as String?,
    tasks: tasks,
  );
}

/// Minimal interface over an LLM. Implemented on-device by flutter_gemma
/// (see Phase 1 in TODO.md). Kept abstract so the Coordinator is unit-testable
/// with a fake client.
abstract interface class LlmClient {
  Future<String> complete({required String system, required String user});
}

/// Runs a planning/re-tasking request with the validate -> one-repair -> fallback
/// loop from the decomposition contract.
class Coordinator {
  const Coordinator(this.llm);
  final LlmClient llm;

  Future<PlannerResponse> plan({
    required String goal,
    String typeGuess = 'unknown',
    String priorAnswers = 'none',
    PlanContext context = PlanContext.plan,
  }) async {
    final user =
        'Goal: $goal\nType (guess, may be wrong): $typeGuess\nAnswers to prior questions: $priorAnswers';
    final system =
        context == PlanContext.retask ? reTaskingSystemPrompt : planningSystemPrompt;

    var raw = await llm.complete(system: system, user: user);
    var obj = _tryDecode(raw);
    var errors = obj == null
        ? ['response was not valid JSON']
        : validatePlannerJson(obj, context: context);

    if (errors.isNotEmpty) {
      final repairUser =
          'Previous response: $raw\nValidation errors:\n- ${errors.join('\n- ')}';
      raw = await llm.complete(system: repairSystemPrompt, user: repairUser);
      obj = _tryDecode(raw);
      errors = obj == null
          ? ['response was not valid JSON']
          : validatePlannerJson(obj, context: context);
    }

    if (obj == null || errors.isNotEmpty) {
      throw CoordinatorException(errors.isEmpty ? ['unknown error'] : errors);
    }
    return parsePlannerResponse(obj);
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

class CoordinatorException implements Exception {
  const CoordinatorException(this.errors);
  final List<String> errors;
  @override
  String toString() => 'CoordinatorException: ${errors.join('; ')}';
}
