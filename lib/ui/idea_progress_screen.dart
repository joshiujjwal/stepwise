import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'widgets.dart';

/// Task detail view with the approval gate and focus timer.
class IdeaProgressScreen extends StatelessWidget {
  const IdeaProgressScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final task = controller.taskById(taskId);
    final idea = controller.ideas.firstWhere((i) => i.id == task.ideaId);

    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              idea.title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _TaskCard(controller: controller, task: task),
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
      margin: EdgeInsets.fromLTRB(indented ? 20 : 0, 0, 0, 0),
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
            Text(
              task.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ..._actionsFor(context),
            if (controller.isTimerRunning(task.id)) ...[
              const SizedBox(height: 8),
              Text(
                'Time left: ${_formatCountdown(controller.remainingFocusSeconds(task.id))}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
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
          const Text('Blocked'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => controller.unstuckTask(task.id),
            child: const Text("I'm unstuck"),
          ),
        ];
      case TaskState.done:
        return [
          Row(children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.tertiary,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text('Done'),
          ]),
        ];
      case TaskState.reTasked:
        return [
          Text(
            'Blocked task replaced by smaller steps below.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ];
    }
  }

  static String _formatCountdown(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final remainingSeconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
