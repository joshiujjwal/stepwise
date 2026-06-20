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
    return Scaffold(
      appBar: AppBar(title: const Text('Idea')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (session?.phase) {
          null || PlanningPhase.idle => _capture(controller),
          PlanningPhase.thinking => _thinking(),
          PlanningPhase.clarifying => _clarify(controller, session!),
          PlanningPhase.proposed => _proposed(controller, session!),
          PlanningPhase.error => _error(controller, session!),
        },
      ),
    );
  }

  Widget _capture(AppController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Write one TODO item.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goal,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. File my 2025 taxes',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final text = _goal.text.trim();
            if (text.isNotEmpty) controller.submitTodoItem(text);
          },
          child: const Text('Chunk TODO'),
        ),
        const SizedBox(height: 8),
        const Text(
          'The agent will enhance it and split it into time-doable chunks you can confirm.',
          style: TextStyle(color: Colors.grey),
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
          SizedBox(height: 12),
          Text('Thinking...'),
        ],
      ),
    );
  }

  Widget _clarify(AppController controller, PlanningSession session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Goal: ${session.goal}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final q in session.questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(q, style: const TextStyle(fontSize: 16)),
          ),
        TextField(
          controller: _answer,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Your answer',
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
    final tasks = session.proposal!.tasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Proposed plan (${tasks.length} steps)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final t = tasks[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(t.title),
                subtitle: Text(t.description),
                trailing: Text('${t.estMinutes}m'),
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: controller.confirmPlan,
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
    final message = _friendlyError(session.error);
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
                "I couldn't plan that cleanly.\n$message",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.discardPlan,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Please try again.';
    final lower = raw.toLowerCase();
    if (lower.contains('failedtopredictsync') ||
        lower.contains('xnnpack delegate failed to reshape') ||
        lower.contains('allocatetensors()')) {
      return 'The selected model could not run on this device/runtime. '
          'Try a smaller model like Gemma 3 1B (.task) or switch to Demo mode.';
    }
    return raw;
  }
}
