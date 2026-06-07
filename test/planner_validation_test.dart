import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stepwise/coordinator/planner.dart';

Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;

/// Load a shared fixture used by both validators (tool/coordinator/fixtures/).
Map<String, dynamic> _fixture(String name) =>
    _decode(File('tool/coordinator/fixtures/$name').readAsStringSync());

void main() {
  test(
      'shared fixtures: valid_plan passes, invalid_extra_keys fails (parity '
      'with validate_plan.py)', () {
    expect(validatePlannerJson(_fixture('valid_plan.json')), isEmpty);
    expect(validatePlannerJson(_fixture('valid_clarify.json')), isEmpty);
    expect(
        validatePlannerJson(_fixture('invalid_extra_keys.json')), isNotEmpty);
    expect(
      validatePlannerJson(_fixture('invalid_evidence_type.json')),
      isNotEmpty,
    );
  });

  test('valid plan passes (parity with valid_plan fixture)', () {
    final obj = _decode('''
    { "action": "propose_plan", "idea_type": "errand",
      "micro_tasks": [
        {"title":"Book the dentist appointment","description":"Call the office.","est_minutes":15,"order_index":1,
         "acceptance_criteria":[{"text":"Appointment confirmed","evidence_type":"checkbox"}]},
        {"title":"Add it to your calendar","description":"Put it on the calendar.","est_minutes":5,"order_index":2,
         "acceptance_criteria":[{"text":"Event on calendar","evidence_type":"checkbox"}]},
        {"title":"Note the insurance member id","description":"Write down member id.","est_minutes":10,"order_index":3,
         "acceptance_criteria":[{"text":"Member id written down","evidence_type":"note"}]}
      ] }
    ''');
    expect(validatePlannerJson(obj), isEmpty);
    expect(parsePlannerResponse(obj), isA<PlanResponse>());
  });

  test('rejects est_minutes out of range', () {
    final obj = _decode('''
    { "action": "propose_plan", "idea_type": "errand",
      "micro_tasks": [
        {"title":"Book the dentist appointment","description":"Call.","est_minutes":120,"order_index":1,
         "acceptance_criteria":[{"text":"Appointment confirmed","evidence_type":"checkbox"}]}
      ] }
    ''');
    final errors = validatePlannerJson(obj);
    expect(errors.any((e) => e.contains('est_minutes')), isTrue);
  });

  test('rejects non-permutation order_index', () {
    final obj = _decode('''
    { "action": "propose_plan", "idea_type": "errand",
      "micro_tasks": [
        {"title":"Task one here","description":"d","est_minutes":15,"order_index":1,
         "acceptance_criteria":[{"text":"crit one","evidence_type":"checkbox"}]},
        {"title":"Task two here","description":"d","est_minutes":15,"order_index":2,
         "acceptance_criteria":[{"text":"crit two","evidence_type":"checkbox"}]},
        {"title":"Task three here","description":"d","est_minutes":15,"order_index":2,
         "acceptance_criteria":[{"text":"crit three","evidence_type":"checkbox"}]}
      ] }
    ''');
    expect(
      validatePlannerJson(obj).any((e) => e.contains('order_index')),
      isTrue,
    );
  });

  test('clarify response is valid', () {
    final obj = _decode(
      '{ "action":"ask_clarifying", "questions":["Are you filing online or with a preparer?"] }',
    );
    expect(validatePlannerJson(obj), isEmpty);
    expect(parsePlannerResponse(obj), isA<ClarifyResponse>());
  });

  test('rejects unexpected top-level keys (parity with invalid_extra_keys)',
      () {
    final obj = _decode('''
    { "action": "propose_plan", "idea_type": "errand", "priority": "high",
      "micro_tasks": [
        {"title":"Book the dentist appointment","description":"Call.","est_minutes":15,"order_index":1,
         "acceptance_criteria":[{"text":"Appointment confirmed","evidence_type":"checkbox"}]},
        {"title":"Add it to your calendar","description":"Put it on the calendar.","est_minutes":5,"order_index":2,
         "acceptance_criteria":[{"text":"Event on calendar","evidence_type":"checkbox"}]}
      ] }
    ''');
    expect(
      validatePlannerJson(obj).any((e) => e.contains('unexpected keys')),
      isTrue,
    );
  });

  test('rejects unexpected keys on a task and a criterion', () {
    final task = _decode('''
    { "action": "propose_plan", "idea_type": "errand",
      "micro_tasks": [
        {"title":"Book the dentist appointment","description":"Call.","est_minutes":15,"order_index":1,"foo":1,
         "acceptance_criteria":[{"text":"Appointment confirmed","evidence_type":"checkbox"}]},
        {"title":"Add it to your calendar","description":"Put it.","est_minutes":5,"order_index":2,
         "acceptance_criteria":[{"text":"Event on calendar","evidence_type":"checkbox","bar":2}]}
      ] }
    ''');
    final errors = validatePlannerJson(task);
    expect(errors.where((e) => e.contains('unexpected keys')).length, 2);
  });

  test('rejects an over-long summary', () {
    final obj = _decode('''
    { "action": "propose_plan", "idea_type": "errand", "summary": "${'x' * 201}",
      "micro_tasks": [
        {"title":"Book the dentist appointment","description":"Call.","est_minutes":15,"order_index":1,
         "acceptance_criteria":[{"text":"Appointment confirmed","evidence_type":"checkbox"}]},
        {"title":"Add it to your calendar","description":"Put it.","est_minutes":5,"order_index":2,
         "acceptance_criteria":[{"text":"Event on calendar","evidence_type":"checkbox"}]}
      ] }
    ''');
    expect(validatePlannerJson(obj).any((e) => e.contains('summary')), isTrue);
  });
}
