import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import 'idea_progress_screen.dart';
import 'widgets.dart';

/// Execute tab - actionable tasks with a duration filter.
class ExecuteScreen extends StatefulWidget {
  const ExecuteScreen({super.key});

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen> {
  DurationBucket? _bucket;
  bool _groupByIdea = true;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final space = context.space;
    return Scaffold(
      appBar: AppBar(title: const Text('Execute')),
      body: Column(
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(space.lg, space.sm, space.lg, space.sm),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: ScreenHeader(
                title: 'Execute',
                subtitle: 'Earn your win one micro task at a time.',
              ),
            ),
          ),
          _filterBar(),
          const Divider(),
          Expanded(child: _list(controller)),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final space = context.space;
    final timeOptions = <(String, DurationBucket?)>[
      ('All', null),
      ('15 min', DurationBucket.m15),
      ('30 min', DurationBucket.m30),
      ('45 min', DurationBucket.m45),
      ('60+', DurationBucket.m60plus),
    ];
    final viewOptions = <(String, bool)>[
      ('Grouped', true),
      ('Flat', false),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(space.sm, space.sm, space.sm, space.md),
      child: Column(
        children: [
          _filterRow(
            'Time:',
            [
              for (final (label, bucket) in timeOptions)
                ChoiceChip(
                  label: Text(label),
                  selected: _bucket == bucket,
                  onSelected: (_) => setState(() => _bucket = bucket),
                ),
            ],
          ),
          SizedBox(height: space.sm),
          _filterRow(
            'View:',
            [
              for (final (label, grouped) in viewOptions)
                ChoiceChip(
                  label: Text(label),
                  selected: _groupByIdea == grouped,
                  onSelected: (_) => setState(() => _groupByIdea = grouped),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterRow(String label, List<Widget> chips) {
    final space = context.space;
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.sm),
          child: Text(label, style: context.texts.labelLarge),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final chip in chips)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: space.xs),
                    child: chip,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(AppController controller) {
    final tasks = controller.availableTasks(bucket: _bucket);
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.space.xl),
          child: Text(
            'No wins to earn yet. Add an idea on the Idea tab, or pick a '
            'different time filter.',
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_groupByIdea) return _groupedList(controller, tasks);
    return _flatList(controller, tasks);
  }

  Widget _flatList(AppController controller, List<MicroTask> tasks) {
    final ideaById = {for (final idea in controller.ideas) idea.id: idea};
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        final idea = ideaById[task.ideaId];
        if (idea == null) return const SizedBox.shrink();
        return _microTaskCard(task: task, idea: idea);
      },
    );
  }

  Widget _groupedList(AppController controller, List<MicroTask> tasks) {
    final space = context.space;
    final ideaById = {for (final idea in controller.ideas) idea.id: idea};
    final grouped = <String, List<MicroTask>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.ideaId, () => []).add(task);
    }
    final groups = <_IdeaTaskGroup>[
      for (final entry in grouped.entries)
        if (ideaById[entry.key] case final idea?)
          _IdeaTaskGroup(
            idea: idea,
            tasks: [...entry.value]
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
            doneCount: controller.progressForIdea(idea.id).done,
            totalCount: controller.progressForIdea(idea.id).total,
          ),
    ]..sort(
        (a, b) => a.tasks.first.orderIndex.compareTo(b.tasks.first.orderIndex),
      );

    return ListView.builder(
      padding: EdgeInsets.only(bottom: space.lg),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: EdgeInsets.fromLTRB(space.lg, space.xs, space.lg, space.sm),
          child: ExpansionTile(
            key: PageStorageKey('idea-group-${group.idea.id}'),
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(group.idea.title, style: context.texts.titleMedium),
            subtitle: Text(
              '${group.idea.type.name} · ${group.doneCount}/${group.totalCount} tasks done',
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(space.lg, 0, space.lg, space.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Micro tasks',
                    style: context.texts.labelMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ),
              for (final task in group.tasks)
                _microTaskCard(
                  task: task,
                  idea: group.idea,
                  margin: EdgeInsets.fromLTRB(
                      space.sm, space.xs, space.sm, space.sm),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _microTaskCard({
    required MicroTask task,
    required Idea idea,
    EdgeInsets? margin,
  }) {
    final space = context.space;
    return Card(
      margin: margin ??
          EdgeInsets.symmetric(horizontal: space.lg, vertical: space.xs),
      child: ListTile(
        title: Text(task.title),
        subtitle: Text('${idea.type.name} · ${idea.title}'),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: stateColor(context, task.state),
          child: Icon(
            stateIcon(task.state),
            size: 16,
            color: stateOnColor(context, task.state),
          ),
        ),
        trailing: DurationBadge(task.estMinutes),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => IdeaProgressScreen(taskId: task.id),
          ),
        ),
      ),
    );
  }
}

class _IdeaTaskGroup {
  const _IdeaTaskGroup({
    required this.idea,
    required this.tasks,
    required this.doneCount,
    required this.totalCount,
  });

  final Idea idea;
  final List<MicroTask> tasks;
  final int doneCount;
  final int totalCount;
}
