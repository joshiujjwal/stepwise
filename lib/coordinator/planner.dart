import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'prompts.dart';

// PlannerResponse parsing + validation + the repair loop.
// The ERROR rules here mirror tool/coordinator/validate_plan.py exactly (a
// response is valid iff there are no errors). The Python reference additionally
// emits non-blocking WARNINGS (vague titles, soft 5-12 task-count) that do not
// affect validity and are not reproduced here. Fixtures under
// tool/coordinator/fixtures/ are the shared regression guard for both.

const Set<String> kEvidenceTypes = {'checkbox', 'note', 'url', 'file'};
const Set<String> kIdeaTypes = {
  'tax',
  'trip',
  'errand',
  'admin',
  'project',
  'other',
};
const int kRepairPreviousResponseMaxChars = 2000;

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
    errors.add(
        '\$.action: must be "ask_clarifying" or "propose_plan", got $action');
  }
  return errors;
}

void _validateClarify(Map<String, dynamic> obj, List<String> errors) {
  _rejectExtraKeys(obj, const {'action', 'questions'}, r'$', errors);
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

/// Reject keys not in [allowed] (mirrors Python `additionalProperties: false`).
void _rejectExtraKeys(
  Map<Object?, Object?> obj,
  Set<String> allowed,
  String path,
  List<String> errors,
) {
  final extra = obj.keys
      .map((k) => '$k')
      .where((k) => !allowed.contains(k))
      .toList()
    ..sort();
  if (extra.isNotEmpty) errors.add('$path: unexpected keys: $extra');
}

void _validatePlan(
  Map<String, dynamic> obj,
  PlanContext context,
  List<String> errors,
) {
  _rejectExtraKeys(
    obj,
    const {'action', 'idea_type', 'summary', 'micro_tasks'},
    r'$',
    errors,
  );
  if (!kIdeaTypes.contains(obj['idea_type'])) {
    errors.add('\$.idea_type: must be one of $kIdeaTypes');
  }
  final summary = obj['summary'];
  if (summary != null && (summary is! String || summary.length > 200)) {
    errors.add('\$.summary: must be a string <= 200 chars');
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
    _rejectExtraKeys(
      t,
      const {
        'title',
        'description',
        'est_minutes',
        'acceptance_criteria',
        'order_index',
      },
      p,
      errors,
    );
    final title = t['title'];
    if (title is! String ||
        title.trim().length < 6 ||
        title.trim().length > 80) {
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
    _rejectExtraKeys(ac, const {'text', 'evidence_type'}, cp, errors);
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
    String? systemPromptOverride,
  }) async {
    final user =
        'Goal: $goal\nType (guess, may be wrong): $typeGuess\nAnswers to prior questions: $priorAnswers';
    final system = systemPromptOverride ??
        (context == PlanContext.retask
            ? reTaskingSystemPrompt
            : planningSystemPrompt);

    var raw = await llm.complete(system: system, user: user);
    debugPrint(
        '[Coordinator] Raw response (first 500 chars): ${raw.substring(0, (raw.length > 500 ? 500 : raw.length))}');
    var obj = _normalizePlannerObject(_tryDecode(raw));
    var errors = obj == null
        ? ['response was not valid JSON']
        : validatePlannerJson(obj, context: context);

    if (errors.isNotEmpty) {
      debugPrint('[Coordinator] Validation errors: $errors');
      final repairPrevious = _truncateForRepair(raw);
      final repairUser =
          'Previous response: $repairPrevious\nValidation errors:\n- ${errors.join('\n- ')}';
      raw = await llm.complete(system: repairSystemPrompt, user: repairUser);
      debugPrint(
          '[Coordinator] Repair response (first 500 chars): ${raw.substring(0, (raw.length > 500 ? 500 : raw.length))}');
      obj = _normalizePlannerObject(_tryDecode(raw));
      errors = obj == null
          ? ['response was not valid JSON']
          : validatePlannerJson(obj, context: context);
    }

    if (obj == null || errors.isNotEmpty) {
      final effectiveErrors = errors.isEmpty ? ['unknown error'] : errors;
      final envelope = {
        'action': 'error',
        'error_type': 'planner_response_invalid',
        'stage': 'parse_validate_repair',
        'errors': effectiveErrors,
      };
      throw CoordinatorException([jsonEncode(envelope)]);
    }
    return parsePlannerResponse(obj);
  }

  static String _truncateForRepair(String value) {
    if (value.length <= kRepairPreviousResponseMaxChars) return value;
    return '${value.substring(0, kRepairPreviousResponseMaxChars)}\n...[truncated]';
  }

  static Map<String, dynamic>? _normalizePlannerObject(
    Map<String, dynamic>? obj,
  ) {
    if (obj == null) return null;
    final action = obj['action'];
    if (action == 'ask_clarifying') return obj;
    if (action == 'propose_plan') {
      return _coerceProposePlanObject(obj);
    }

    // Tolerate on-device models that drop the top-level "action" but still
    // emit a task list under a known alias (micro_tasks/plan/tasks/steps).
    // Small models (e.g. Gemma 3n E2B) frequently do this, so infer a
    // propose_plan rather than failing validation on a missing action.
    if (_firstTaskList(obj) != null) {
      return _coerceProposePlanObject(obj);
    }

    return obj;
  }

  /// The first list found under any known task-list alias, or null.
  static List<Object?>? _firstTaskList(Map<String, dynamic> obj) {
    for (final key in const ['micro_tasks', 'plan', 'tasks', 'steps']) {
      final value = obj[key];
      if (value is List && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic> _coerceProposePlanObject(
    Map<String, dynamic> obj,
  ) {
    final rawTasks = _firstTaskList(obj) ?? const <Object?>[];

    final normalized = <Map<String, dynamic>>[];
    for (var i = 0; i < rawTasks.length; i++) {
      final task = _normalizeTaskItem(rawTasks[i], i);
      if (task != null) normalized.add(task);
    }

    normalized.sort((a, b) =>
        (a['order_index'] as int).compareTo(b['order_index'] as int));
    final canonicalTasks = <Map<String, dynamic>>[
      for (var i = 0; i < normalized.length; i++)
        {
          ...normalized[i],
          'order_index': i + 1,
        }
    ];

    final summary = _asString(obj['summary']);
    return {
      'action': 'propose_plan',
      'idea_type': _normalizeIdeaType(obj['idea_type'] ?? obj['type']),
      if (summary != null) 'summary': summary,
      'micro_tasks': canonicalTasks,
    };
  }

  /// Coerces a single (possibly malformed) task entry into the canonical task
  /// shape. Tolerates the drift seen from on-device models:
  /// - the payload nested under a `task` key,
  /// - a missing `title` (derived from the description),
  /// - a criterion-shaped item (`{text, evidence_type}`) used as a task.
  static Map<String, dynamic>? _normalizeTaskItem(Object? item, int index) {
    if (item is! Map) return null;

    // Unwrap `{order_index, task: {...}}` while keeping the outer order_index.
    final inner = item['task'];
    final fields = inner is Map ? inner : item;

    final title = _asString(fields['title']) ??
        _asString(item['title']) ??
        _asString(fields['action']) ??
        _asString(item['action']) ??
        _deriveTitle(_asString(fields['description'])) ??
        // Criterion-shaped item: use its text as the task title.
        _deriveTitle(_asString(fields['text']) ?? _asString(item['text'])) ??
        'Complete task ${index + 1}';

    final description = _asString(fields['description']) ??
        _asString(item['description']) ??
        title;

    final order =
        _asInt(item['order_index']) ?? _asInt(fields['order_index']) ?? (index + 1);
    final estMinutes =
        _normalizeEstMinutes(fields['est_minutes'] ?? item['est_minutes']);
    final criteria = _normalizeCriteria(
      fields['acceptance_criteria'] ?? fields['criteria'] ?? item['acceptance_criteria'],
      title,
    );

    return {
      'title': title,
      'description': description,
      'est_minutes': estMinutes,
      'order_index': order,
      'acceptance_criteria': criteria,
    };
  }

  /// Derives a valid 6-80 char task title from free text (e.g. a description),
  /// trimming to the first sentence/clause. Returns null when [raw] is empty.
  static String? _deriveTitle(String? raw) {
    final text = _asString(raw);
    if (text == null) return null;
    var title = text.split(RegExp(r'[.!?\n]')).first.trim();
    if (title.isEmpty) title = text.trim();
    if (title.length > 80) title = '${title.substring(0, 77).trimRight()}...';
    if (title.length < 6) title = text.trim();
    if (title.length > 80) title = title.substring(0, 80).trimRight();
    return title.length < 6 ? null : title;
  }

  static String? _asString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _normalizeIdeaType(Object? raw) {
    final value = _asString(raw)?.toLowerCase();
    if (value == null) return 'other';
    if (kIdeaTypes.contains(value)) return value;
    if (value.contains('tax')) return 'tax';
    if (value.contains('trip') || value.contains('travel')) return 'trip';
    if (value.contains('errand')) return 'errand';
    if (value.contains('admin')) return 'admin';
    if (value.contains('project')) return 'project';
    return 'other';
  }

  static int _normalizeEstMinutes(Object? raw) {
    final parsed = _asInt(raw) ?? 15;
    final rounded = ((parsed / 5).round() * 5).clamp(5, 60);
    return rounded;
  }

  static List<Map<String, String>> _normalizeCriteria(
    Object? raw,
    String fallbackTitle,
  ) {
    if (raw is! List || raw.isEmpty) {
      return [
        {'text': '$fallbackTitle completed', 'evidence_type': 'checkbox'}
      ];
    }

    final criteria = <Map<String, String>>[];
    for (final item in raw) {
      if (criteria.length >= 4) break;
      if (item is String) {
        final text = item
            .replaceFirst(
                RegExp(r'^\s*checkbox\s*:\s*', caseSensitive: false), '')
            .trim();
        if (text.isEmpty) continue;
        criteria.add({'text': text, 'evidence_type': 'checkbox'});
        continue;
      }
      if (item is Map) {
        final text = _asString(item['text']) ??
            _asString(item['criterion']) ??
            _asString(item['description']);
        if (text == null) continue;
        final evidence = _asString(item['evidence_type'])?.toLowerCase();
        criteria.add({
          'text': text,
          'evidence_type':
              kEvidenceTypes.contains(evidence) ? evidence! : 'checkbox',
        });
      }
    }

    if (criteria.isNotEmpty) return criteria;
    return [
      {'text': '$fallbackTitle completed', 'evidence_type': 'checkbox'}
    ];
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    final candidates = <String>[
      raw,
      _normalizeJsonCandidate(raw),
      ..._extractFencedBlocks(raw),
      ..._extractFencedBlocks(_normalizeJsonCandidate(raw)),
    ];

    for (final source in candidates) {
      final direct = _decodeToMap(source);
      if (direct != null) return direct;

      final extracted = _extractJsonObjectCandidates(source);
      for (final candidate in extracted) {
        final parsed = _decodeToMap(candidate) ??
            _decodeToMap(_normalizeJsonCandidate(candidate));
        if (parsed != null) return parsed;
      }
    }
    debugPrint('[_tryDecode] No valid JSON object decoded');
    return null;
  }

  static List<String> _extractFencedBlocks(String raw) {
    final blocks = <String>[];
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    for (final match in fence.allMatches(raw)) {
      final block = match.group(1)?.trim();
      if (block != null && block.isNotEmpty) blocks.add(block);
    }
    return blocks;
  }

  static Map<String, dynamic>? _decodeToMap(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is String && decoded != trimmed) {
        return _decodeToMap(decoded);
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  static String _normalizeJsonCandidate(String raw) {
    var normalized = raw.trim();
    normalized = _stripCodeFence(normalized);
    normalized = normalized
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
    normalized = _removeTrailingCommas(normalized);
    return normalized;
  }

  static String _stripCodeFence(String raw) {
    if (!raw.startsWith('```') || !raw.endsWith('```')) return raw;
    final firstLineEnd = raw.indexOf('\n');
    if (firstLineEnd == -1 || firstLineEnd >= raw.length - 3) return raw;
    return raw.substring(firstLineEnd + 1, raw.length - 3).trim();
  }

  static String _removeTrailingCommas(String raw) {
    final out = StringBuffer();
    var inString = false;
    var escaping = false;

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (inString) {
        out.write(ch);
        if (escaping) {
          escaping = false;
        } else if (ch == r'\') {
          escaping = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        out.write(ch);
        continue;
      }
      if (ch == ',') {
        final next = _nextNonWhitespace(raw, i + 1);
        if (next == '}' || next == ']') continue;
      }
      out.write(ch);
    }
    return out.toString();
  }

  static String? _nextNonWhitespace(String raw, int start) {
    for (var i = start; i < raw.length; i++) {
      final ch = raw[i];
      if (ch.trim().isNotEmpty) return ch;
    }
    return null;
  }

  static List<String> _extractJsonObjectCandidates(String raw) {
    final candidates = <String>[];
    var depth = 0;
    var inString = false;
    var escaping = false;
    var start = -1;

    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (ch == r'\') {
          escaping = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
        continue;
      }
      if (ch == '}') {
        if (depth == 0) continue;
        depth--;
        if (depth == 0 && start >= 0) {
          candidates.add(raw.substring(start, i + 1));
          start = -1;
        }
      }
    }
    return candidates;
  }
}

class CoordinatorException implements Exception {
  const CoordinatorException(this.errors);
  final List<String> errors;
  @override
  String toString() => 'CoordinatorException: ${errors.join('; ')}';
}
