import 'package:flutter/material.dart';

import '../coordinator/planner.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../state/planning_job.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

/// Review + edit + submit a background planning job (spec §11, background).
///
/// Opened from the Idea tab's job inbox. For a ready job the user can tweak each
/// step's title/description/duration, then submit (persist as an idea + tasks)
/// or discard. Clarifying jobs can be answered to refine; errors can be retried.
class ReviewPlanScreen extends StatefulWidget {
  const ReviewPlanScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ReviewPlanScreen> createState() => _ReviewPlanScreenState();
}

class _ReviewPlanScreenState extends State<ReviewPlanScreen> {
  final TextEditingController _answer = TextEditingController();
  List<_EditableTask>? _tasks;
  String? _loadedForProposal;

  @override
  void dispose() {
    _answer.dispose();
    for (final t in _tasks ?? const <_EditableTask>[]) {
      t.dispose();
    }
    super.dispose();
  }

  // Rebuild editable rows from the job's proposal the first time we see it (or
  // if the background run replaced it), never on every rebuild — otherwise
  // in-progress edits would be discarded.
  void _syncFrom(PlanningJob job) {
    final signature = '${job.id}:${job.proposal?.tasks.length}';
    if (_loadedForProposal == signature && _tasks != null) return;
    for (final t in _tasks ?? const <_EditableTask>[]) {
      t.dispose();
    }
    _tasks = [
      for (final t in job.proposal?.tasks ?? const <PlannedTask>[])
        _EditableTask.from(t),
    ];
    _loadedForProposal = signature;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final job = controller.jobById(widget.jobId);
    return Scaffold(
      appBar: AppBar(title: const Text('Review plan')),
      body: Padding(
        padding: EdgeInsets.all(context.space.lg),
        child: job == null
            ? _missing(context)
            : switch (job.status) {
                PlanningJobStatus.ready => _review(context, controller, job),
                PlanningJobStatus.clarifying =>
                  _clarify(context, controller, job),
                PlanningJobStatus.thinking => _thinking(context),
                PlanningJobStatus.error => _error(context, controller, job),
              },
      ),
    );
  }

  Widget _missing(BuildContext context) => Center(
        child: Text('This plan is no longer available.',
            style: context.texts.bodyLarge),
      );

  Widget _thinking(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: context.space.md),
            const Text('Still working on this plan…'),
          ],
        ),
      );

  Widget _review(
      BuildContext context, AppController controller, PlanningJob job) {
    _syncFrom(job);
    final space = context.space;
    final tasks = _tasks!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Review plan (${tasks.length} steps)',
          subtitle: 'Edit anything, then submit to start earning your win.',
        ),
        SizedBox(height: space.md),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text('No steps left — add some or discard.',
                      style: context.texts.bodyMedium))
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, i) => _taskCard(context, tasks[i], i),
                ),
        ),
        SizedBox(height: space.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed:
                    tasks.isEmpty ? null : () => _submit(context, controller),
                child: const Text('Submit plan'),
              ),
            ),
            SizedBox(width: space.md),
            OutlinedButton(
              onPressed: () {
                controller.discardJob(job.id);
                Navigator.of(context).pop();
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskCard(BuildContext context, _EditableTask task, int index) {
    final space = context.space;
    return Card(
      margin: EdgeInsets.only(bottom: space.sm),
      child: Padding(
        padding: EdgeInsets.all(space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      context.colors.primary.withValues(alpha: 0.14),
                  child: Text('${index + 1}',
                      style: context.texts.labelLarge
                          ?.copyWith(color: context.colors.primary)),
                ),
                SizedBox(width: space.sm),
                Expanded(
                  child: TextField(
                    controller: task.title,
                    decoration: const InputDecoration(
                      labelText: 'Step title',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove step',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    task.dispose();
                    _tasks!.remove(task);
                  }),
                ),
              ],
            ),
            SizedBox(height: space.sm),
            TextField(
              controller: task.description,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What to do',
                isDense: true,
              ),
            ),
            SizedBox(height: space.sm),
            Row(
              children: [
                Text('Estimate', style: context.texts.bodyMedium),
                SizedBox(width: space.md),
                DropdownButton<int>(
                  value: task.estMinutes,
                  items: [
                    for (var m = 5; m <= 60; m += 5)
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) =>
                      setState(() => task.estMinutes = v ?? task.estMinutes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _clarify(
      BuildContext context, AppController controller, PlanningJob job) {
    final space = context.space;
    return ListView(
      children: [
        const ScreenHeader(
          title: 'A few details needed',
          subtitle: 'Answer once so the plan can be cleaner.',
        ),
        SizedBox(height: space.md),
        Card(
          child: Padding(
            padding: EdgeInsets.all(space.md),
            child: Text('Goal: ${job.goal}',
                style: context.texts.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        SizedBox(height: space.md),
        for (var i = 0; i < job.questions.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: space.sm),
            child: Text('${i + 1}. ${job.questions[i]}',
                style: context.texts.bodyLarge),
          ),
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
          onPressed: () {
            controller.answerJob(job.id, _answer.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('Send answer'),
        ),
      ],
    );
  }

  Widget _error(
      BuildContext context, AppController controller, PlanningJob job) {
    final space = context.space;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.colors.error, size: 40),
          SizedBox(height: space.sm),
          Text("We couldn't create this plan.",
              style: context.texts.titleMedium, textAlign: TextAlign.center),
          if (job.error != null) ...[
            SizedBox(height: space.sm),
            Text(job.error!,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
          SizedBox(height: space.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () {
                  controller.answerJob(job.id, '');
                  Navigator.of(context).pop();
                },
                child: const Text('Retry'),
              ),
              SizedBox(width: space.md),
              OutlinedButton(
                onPressed: () {
                  controller.discardJob(job.id);
                  Navigator.of(context).pop();
                },
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context, AppController controller) {
    final edited = PlanResponse(
      ideaType: controller.jobById(widget.jobId)?.proposal?.ideaType ?? 'other',
      summary: controller.jobById(widget.jobId)?.proposal?.summary,
      tasks: [
        for (var i = 0; i < _tasks!.length; i++) _tasks![i].toPlanned(i),
      ],
    );
    controller.updateJobProposal(widget.jobId, edited);
    controller.submitJob(widget.jobId);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan saved. Open Execute and earn your first win.'),
      ),
    );
  }
}

/// Mutable editing buffer for one planned step. Acceptance criteria pass through
/// unchanged (not editable in v1) so the acceptance gate stays intact.
class _EditableTask {
  _EditableTask({
    required this.title,
    required this.description,
    required this.estMinutes,
    required this.criteria,
  });

  factory _EditableTask.from(PlannedTask t) => _EditableTask(
        title: TextEditingController(text: t.title),
        description: TextEditingController(text: t.description),
        estMinutes: t.estMinutes,
        criteria: t.acceptanceCriteria,
      );

  final TextEditingController title;
  final TextEditingController description;
  int estMinutes;
  final List<PlannedCriterion> criteria;

  PlannedTask toPlanned(int orderIndex) => PlannedTask(
        title: title.text.trim(),
        description: description.text.trim(),
        estMinutes: estMinutes,
        orderIndex: orderIndex,
        acceptanceCriteria: criteria,
      );

  void dispose() {
    title.dispose();
    description.dispose();
  }
}
