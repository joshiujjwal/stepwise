import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'widgets.dart';

/// Per-idea progress - ordered tasks, "step N of M", the acceptance gate, the
/// focus timer, and re-tasking. Wireframe: docs/wireframes/2-idea-progress.
class IdeaProgressScreen extends StatelessWidget {
  const IdeaProgressScreen({super.key, required this.ideaId});

  final String ideaId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tasks = controller.tasksForIdea(ideaId);
    final progress = controller.progressForIdea(ideaId);
    final idea = controller.ideas.firstWhere((i) => i.id == ideaId);

    return Scaffold(
      appBar: AppBar(title: Text(idea.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${progress.currentStep} of ${progress.total}  -  '
                  '${progress.percentComplete}% complete',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress.percentComplete / 100),
                const SizedBox(height: 4),
                const Text(
                  'Order is a suggestion - do any available task first.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, i) =>
                  _TaskCard(controller: controller, task: tasks[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.controller, required this.task});
  final AppController controller;
  final MicroTask task;

  @override
  Widget build(BuildContext context) {
    final indented = task.parentTaskId != null;
    return Card(
      margin: EdgeInsets.fromLTRB(indented ? 32 : 12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatePill(task.state),
                const Spacer(),
                DurationBadge(task.estMinutes),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(task.description,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            ..._actionsFor(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsFor(BuildContext context) {
    switch (task.state) {
      case TaskState.todo:
        return [
          Wrap(spacing: 8, children: [
            FilledButton(
              onPressed: () => controller.startTask(task.id),
              child: const Text('Start'),
            ),
            OutlinedButton(
              onPressed: () => controller.retask(task.id),
              child: const Text('Break it down'),
            ),
          ]),
        ];
      case TaskState.inProgress:
        return [
          Wrap(spacing: 8, children: [
            if (controller.isTimerRunning(task.id))
              OutlinedButton.icon(
                onPressed: () => controller.stopTimer(task.id),
                icon: const Icon(Icons.stop),
                label: const Text('Stop timer'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => controller.startTimer(task.id),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Focus timer'),
              ),
            FilledButton(
              onPressed: () => controller.submitTask(task.id),
              child: const Text('Submit for approval'),
            ),
            OutlinedButton(
              onPressed: () => controller.retask(task.id),
              child: const Text('Break it down'),
            ),
            TextButton(
              onPressed: () => _block(context),
              child: const Text("I'm stuck"),
            ),
          ]),
        ];
      case TaskState.awaitingApproval:
        return [
          const Text('Definition of done',
              style: TextStyle(fontWeight: FontWeight.bold)),
          for (final c in task.acceptanceCriteria)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: c.satisfied,
              onChanged: c.satisfied
                  ? null
                  : (_) => controller.satisfyCriterion(
                        task.id,
                        c.id,
                        evidenceValue: c.evidenceType == EvidenceType.checkbox
                            ? null
                            : '(provided)',
                      ),
              title: Text(c.text),
              subtitle: c.evidenceType == EvidenceType.checkbox
                  ? null
                  : Text('evidence: ${c.evidenceType.name}'),
            ),
          Wrap(spacing: 8, children: [
            FilledButton(
              onPressed: task.allCriteriaSatisfied
                  ? () => controller.approveTask(task.id)
                  : null,
              child: const Text('Approve -> Done'),
            ),
            OutlinedButton(
              onPressed: () => controller.rejectTask(task.id),
              child: const Text('Not yet'),
            ),
          ]),
        ];
      case TaskState.blocked:
        return [
          OutlinedButton(
            onPressed: () => controller.retask(task.id),
            child: const Text('Break this down'),
          ),
        ];
      case TaskState.done:
        return [
          const Row(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 18),
            SizedBox(width: 6),
            Text('Done'),
          ]),
        ];
      case TaskState.reTasked:
        return [
          const Text('Re-tasked into smaller steps below.',
              style: TextStyle(color: Colors.grey)),
        ];
    }
  }

  Future<void> _block(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("What's blocking you?"),
        content: TextField(
          controller: reasonController,
          decoration:
              const InputDecoration(hintText: 'e.g. missing a document'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Mark stuck'),
          ),
        ],
      ),
    );
    if (reason != null) controller.blockTask(task.id, reason);
  }
}
