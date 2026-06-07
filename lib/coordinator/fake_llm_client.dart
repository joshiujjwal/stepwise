import 'planner.dart';
import 'demo_planner.dart';

/// An [LlmClient] with no network/model. Two modes:
/// - scripted: returns queued responses in order (precise tests, e.g. force a
///   clarify turn or an invalid->repair sequence);
/// - generative (default): uses [DemoPlanner] to produce a valid plan/retask
///   from the prompt, so the app works in "demo mode" with no model.
class FakeLlmClient implements LlmClient {
  FakeLlmClient(
      {List<String>? scripted, DemoPlanner planner = const DemoPlanner()})
      : _scripted = [...?scripted],
        _planner = planner;

  final List<String> _scripted;
  final DemoPlanner _planner;

  /// Captured (system, user) pairs, for assertions in tests.
  final List<({String system, String user})> calls = [];

  @override
  Future<String> complete(
      {required String system, required String user}) async {
    calls.add((system: system, user: user));
    if (_scripted.isNotEmpty) return _scripted.removeAt(0);

    final goal = _extract(user, 'Goal:');
    if (system.contains('stuck or too big')) {
      return _planner.retaskJson(goal.isEmpty ? 'this step' : goal);
    }
    return _planner.planJson(goal.isEmpty ? user.trim() : goal);
  }

  static String _extract(String user, String label) {
    for (final line in user.split('\n')) {
      if (line.trimLeft().startsWith(label)) {
        return line.substring(line.indexOf(label) + label.length).trim();
      }
    }
    return '';
  }
}
