import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
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
    final space = context.space;

    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: ListView(
        padding: EdgeInsets.all(space.lg),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: space.md),
            child: Text(
              idea.title,
              style: context.texts.labelLarge
                  ?.copyWith(color: context.colors.onSurfaceVariant),
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
    final space = context.space;
    final indented = task.parentTaskId != null;
    return Card(
      margin: EdgeInsets.only(left: indented ? space.xl : 0),
      child: Padding(
        padding: EdgeInsets.all(space.lg),
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
            SizedBox(height: space.md),
            Text(
              task.description,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            SizedBox(height: space.md),
            ..._actionsFor(context),
            if (controller.isTimerRunning(task.id)) ...[
              SizedBox(height: space.md),
              Text(
                'Time left: ${_formatCountdown(controller.remainingFocusSeconds(task.id))}',
                style: context.texts.titleMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsFor(BuildContext context) {
    final space = context.space;
    switch (task.state) {
      case TaskState.todo:
        return [
          Wrap(spacing: space.sm, children: [
            FilledButton(
              onPressed: () => controller.startTask(task.id),
              child: const Text('Start'),
            ),
          ]),
        ];
      case TaskState.inProgress:
        return [
          Wrap(spacing: space.sm, runSpacing: space.sm, children: [
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
          Text('Definition of done', style: context.texts.titleMedium),
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
          Wrap(spacing: space.sm, runSpacing: space.sm, children: [
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
          Text('Blocked', style: context.texts.bodyMedium),
          SizedBox(height: space.sm),
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
              color: stateOnColor(context, TaskState.done),
              size: 18,
            ),
            SizedBox(width: space.xs),
            Text('Done', style: context.texts.bodyMedium),
          ]),
        ];
      case TaskState.reTasked:
        return [
          Text(
            'Blocked task replaced by smaller steps below.',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
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
