import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../state/app_scope.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Idea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhaseHeader(phase: phase),
            const SizedBox(height: 16),
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
    final theme = Theme.of(context);
    final text = _goal.text.trim();
    return ListView(
      children: [
        Text(
          'Capture one TODO',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep it simple: one task, one sentence. We will chunk it into clear next steps so you can earn your win.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
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
                border: OutlineInputBorder(),
                labelText: 'Your TODO',
                hintText: 'Describe one TODO',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${text.characters.length} characters',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        Text(
          'Review the plan before saving, then earn your win one step at a time.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _thinking() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Thinking...',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Building tiny, time-doable steps so you can earn your win.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _clarify(AppController controller, PlanningSession session) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(
          'A few clarifying details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Answer once so the plan can be cleaner.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'TODO: ${session.goal}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < session.questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${i + 1}. ${session.questions[i]}',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _answer,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Your answer',
            hintText: 'Add details that help chunk this better',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => controller.submitAnswers(_answer.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }

  Widget _proposed(AppController controller, PlanningSession session) {
    final theme = Theme.of(context);
    final tasks = session.proposal!.tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Proposed plan (${tasks.length} steps)',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Review quickly, then confirm and start earning your win.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final t = tasks[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(t.title),
                  subtitle: Text(t.description),
                  trailing: Text('${t.estMinutes}m'),
                ),
              );
            },
          ),
        ),
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
            const SizedBox(width: 12),
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
    final presentation = _friendlyError(session.error);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(
                presentation.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                presentation.body,
                textAlign: TextAlign.center,
              ),
              if (presentation.hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  presentation.hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
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
        const SizedBox(width: 8),
        _StepDot(index: 1, active: active, label: 'Clarify'),
        const SizedBox(width: 8),
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
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final idleColor = theme.colorScheme.surfaceContainerHighest;
    final textColor = selected ? selectedColor : theme.colorScheme.onSurface;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.12) : idleColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
