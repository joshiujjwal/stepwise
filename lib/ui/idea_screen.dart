import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../state/engine_controller.dart';
import '../state/engine_scope.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Idea tab - conversational capture (clarify -> streamed plan -> Confirm/Revise).
/// Wireframe: docs/wireframes/6-idea-capture. Spec sections 4 and 11.
class IdeaScreen extends StatefulWidget {
  const IdeaScreen({super.key});

  @override
  State<IdeaScreen> createState() => _IdeaScreenState();
}

class _IdeaScreenState extends State<IdeaScreen> {
  final TextEditingController _goal = TextEditingController();
  final TextEditingController _answer = TextEditingController();

  @override
  void dispose() {
    _goal.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final session = controller.session;
    final phase = session?.phase;
    final space = context.space;
    return Scaffold(
      appBar: AppBar(title: const Text('Idea')),
      body: Padding(
        padding: EdgeInsets.all(space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhaseHeader(phase: phase),
            SizedBox(height: space.lg),
            Expanded(
              child: switch (phase) {
                null || PlanningPhase.idle => _capture(controller),
                PlanningPhase.thinking => _thinking(),
                PlanningPhase.clarifying => _clarify(controller, session!),
                PlanningPhase.proposed => _proposed(controller, session!),
                PlanningPhase.error => _error(controller, session!),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _capture(AppController controller) {
    final space = context.space;
    final text = _goal.text.trim();
    return ListView(
      children: [
        const ScreenHeader(
          title: 'Capture one TODO',
          subtitle:
              'Keep it simple: one task, one sentence. We will chunk it into '
              'clear next steps so you can earn your win.',
        ),
        SizedBox(height: space.lg),
        Tooltip(
          message: 'Describe one TODO you want to capture.',
          child: Semantics(
            label: 'TODO input',
            hint: 'Enter one task to split into smaller steps.',
            textField: true,
            child: TextField(
              controller: _goal,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Your TODO',
                hintText: 'Describe one TODO',
              ),
            ),
          ),
        ),
        SizedBox(height: space.sm),
        Text(
          '${text.characters.length} characters',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
          textAlign: TextAlign.right,
        ),
        SizedBox(height: space.md),
        Tooltip(
          message: 'Split this TODO into smaller steps.',
          child: Semantics(
            button: true,
            label: 'Chunk TODO',
            hint: 'Creates a plan from the TODO you entered.',
            child: FilledButton(
              onPressed: () {
                final value = _goal.text.trim();
                if (value.isNotEmpty) controller.submitTodoItem(value);
              },
              child: const Text('Chunk TODO'),
            ),
          ),
        ),
        SizedBox(height: space.sm),
        Text(
          'Review the plan before saving, then earn your win one step at a time.',
          style: context.texts.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _thinking() {
    // On-device inference returns no completion %, and speed varies a lot
    // between phones. Show an eased, time-based progress bar (honest: it never
    // claims 100% — the screen swaps to the result when planning finishes)
    // instead of a bare spinner.
    final onGemma = EngineScope.maybeOf(context)?.mode == EngineMode.gemma;
    return _ThinkingView(onGemma: onGemma);
  }

  Widget _clarify(AppController controller, PlanningSession session) {
    final space = context.space;
    return ListView(
      children: [
        const ScreenHeader(
          title: 'A few clarifying details',
          subtitle: 'Answer once so the plan can be cleaner.',
        ),
        SizedBox(height: space.lg),
        Card(
          child: Padding(
            padding: EdgeInsets.all(space.md),
            child: Text(
              'TODO: ${session.goal}',
              style: context.texts.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: space.md),
        for (var i = 0; i < session.questions.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: space.sm),
            child: Text(
              '${i + 1}. ${session.questions[i]}',
              style: context.texts.bodyLarge,
            ),
          ),
        SizedBox(height: space.xs),
        TextField(
          controller: _answer,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            hintText: 'Add details that help chunk this better',
          ),
        ),
        SizedBox(height: space.md),
        FilledButton(
          onPressed: () => controller.submitAnswers(_answer.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }

  Widget _proposed(AppController controller, PlanningSession session) {
    final space = context.space;
    final tasks = session.proposal!.tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Proposed plan (${tasks.length} steps)',
          subtitle: 'Review quickly, then confirm and start earning your win.',
        ),
        SizedBox(height: space.md),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final t = tasks[i];
              return Card(
                margin: EdgeInsets.only(bottom: space.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        context.colors.primary.withValues(alpha: 0.14),
                    child: Text(
                      '${i + 1}',
                      style: context.texts.labelLarge
                          ?.copyWith(color: context.colors.primary),
                    ),
                  ),
                  title: Text(t.title),
                  subtitle: Text(t.description),
                  trailing: DurationBadge(t.estMinutes),
                ),
              );
            },
          ),
        ),
        SizedBox(height: space.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  controller.confirmPlan();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Plan saved. Open Execute and earn your first win.',
                      ),
                    ),
                  );
                },
                child: const Text('Confirm plan'),
              ),
            ),
            SizedBox(width: space.md),
            OutlinedButton(
              onPressed: controller.discardPlan,
              child: const Text('Start over'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _error(AppController controller, PlanningSession session) {
    final space = context.space;
    final presentation = _friendlyError(session.error);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: context.colors.error, size: 40),
              SizedBox(height: space.sm),
              Text(
                presentation.title,
                textAlign: TextAlign.center,
                style: context.texts.titleMedium,
              ),
              SizedBox(height: space.sm),
              Text(presentation.body, textAlign: TextAlign.center),
              if (presentation.hint != null) ...[
                SizedBox(height: space.sm),
                Text(
                  presentation.hint!,
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
              SizedBox(height: space.md),
              FilledButton(
                onPressed: controller.discardPlan,
                child: const Text('Back to capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ErrorPresentation _friendlyError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _ErrorPresentation(
        title: "We couldn't create a plan this time.",
        body: 'Please try again.',
      );
    }
    final lower = raw.toLowerCase();
    if (lower.contains('failedtopredictsync') ||
        lower.contains('xnnpack delegate failed to reshape') ||
        lower.contains('allocatetensors()')) {
      return const _ErrorPresentation(
        title: 'Your selected model could not run on this device.',
        body: 'Switch to Demo mode or use a smaller on-device model.',
        hint: 'Open the Settings tab to change engine mode.',
      );
    }
    if (lower.contains('json') ||
        lower.contains('schema') ||
        lower.contains('validation')) {
      return const _ErrorPresentation(
        title: "We couldn't parse the plan response cleanly.",
        body: 'Try once more with the same TODO.',
        hint: 'If it repeats, simplify the TODO sentence and retry.',
      );
    }
    return _ErrorPresentation(
      title: "We couldn't create a plan this time.",
      body: raw,
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.phase});
  final PlanningPhase? phase;

  @override
  Widget build(BuildContext context) {
    final active = switch (phase) {
      null || PlanningPhase.idle => 0,
      PlanningPhase.thinking || PlanningPhase.clarifying => 1,
      PlanningPhase.proposed => 2,
      PlanningPhase.error => 0,
    };

    return Row(
      children: [
        _StepDot(index: 0, active: active, label: 'Capture'),
        SizedBox(width: context.space.sm),
        _StepDot(index: 1, active: active, label: 'Clarify'),
        SizedBox(width: context.space.sm),
        _StepDot(index: 2, active: active, label: 'Review'),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.active,
    required this.label,
  });
  final int index;
  final int active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = index <= active;
    final space = context.space;
    final selectedColor = context.colors.primary;
    final idleColor = context.colors.surfaceContainerHighest;
    final textColor = selected ? selectedColor : context.colors.onSurface;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: space.sm, horizontal: space.md),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.12) : idleColor,
          borderRadius: context.radius.pillAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: textColor,
            ),
            SizedBox(width: space.xs),
            Text(
              label,
              style: context.texts.labelMedium
                  ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPresentation {
  const _ErrorPresentation({
    required this.title,
    required this.body,
    this.hint,
  });

  final String title;
  final String body;
  final String? hint;
}

/// Eased, time-based estimate (0..0.97) for the on-device planning wait.
///
/// Inference exposes no real completion %, so we approach the target
/// asymptotically: the bar moves quickly at first, then slows near the top so
/// it never appears stuck on a slow phone and never lies by hitting 100% (the
/// screen swaps to the result the moment planning actually finishes).
double estimatedThinkingProgress(Duration elapsed, Duration expected) {
  final t = elapsed.inMilliseconds.toDouble();
  final target = expected.inMilliseconds <= 0 ? 1.0 : expected.inMilliseconds;
  final p = 1 - math.exp(-3 * t / target);
  return p.clamp(0.0, 0.97);
}

/// Animated "Thinking…" state: a determinate-looking progress bar driven by
/// elapsed time, a live seconds counter, rotating reassurance, and a gentle
/// slow-device hint. Adapts its pacing to whether on-device Gemma is active.
class _ThinkingView extends StatefulWidget {
  const _ThinkingView({required this.onGemma});

  /// On-device Gemma is far slower (and device-dependent) than the offline demo
  /// planner, so we pace the bar and surface a slow hint accordingly.
  final bool onGemma;

  @override
  State<_ThinkingView> createState() => _ThinkingViewState();
}

class _ThinkingViewState extends State<_ThinkingView> {
  static const _messages = [
    'Breaking your TODO into tiny, time-doable steps…',
    'Keeping everything on your device — no internet needed…',
    'Shaping each step so you can earn a quick win…',
    'Almost there…',
  ];

  Timer? _timer;
  Duration _elapsed = Duration.zero;

  Duration get _expected =>
      widget.onGemma ? const Duration(seconds: 18) : const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 120));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final progress = estimatedThinkingProgress(_elapsed, _expected);
    final seconds = _elapsed.inSeconds;
    final message = _messages[(seconds ~/ 4) % _messages.length];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thinking…',
                textAlign: TextAlign.center,
                style: context.texts.titleMedium,
              ),
              SizedBox(height: space.md),
              Semantics(
                label: 'Planning in progress',
                value: '${(progress * 100).round()} percent',
                child: ClipRRect(
                  borderRadius: context.radius.pillAll,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: context.colors.surfaceContainerHighest,
                  ),
                ),
              ),
              SizedBox(height: space.sm),
              Text(
                '${seconds}s elapsed',
                textAlign: TextAlign.center,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              SizedBox(height: space.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
