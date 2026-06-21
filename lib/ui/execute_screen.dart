import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execute'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Earn your win one micro task at a time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          _filterBar(),
          const Divider(height: 1),
          Expanded(child: _list(controller)),
        ],
      ),
    );
  }

  Widget _filterBar() {
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Time:'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, bucket) in timeOptions)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _bucket == bucket,
                            onSelected: (_) => setState(() => _bucket = bucket),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('View:'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (label, grouped) in viewOptions)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _groupByIdea == grouped,
                            onSelected: (_) =>
                                setState(() => _groupByIdea = grouped),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list(AppController controller) {
    final tasks = controller.availableTasks(bucket: _bucket);
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No wins to earn yet. Add an idea on the Idea tab, or pick a '
            'different time filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ExpansionTile(
            key: PageStorageKey('idea-group-${group.idea.id}'),
            initiallyExpanded: true,
            title: Text(group.idea.title),
            subtitle: Text(
              '${group.idea.type.name} · ${group.doneCount}/${group.totalCount} tasks done',
            ),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Micro tasks'),
                ),
              ),
              for (final task in group.tasks)
                _microTaskCard(
                  task: task,
                  idea: group.idea,
                  margin: const EdgeInsets.fromLTRB(8, 2, 8, 6),
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
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  }) {
    return Card(
      margin: margin,
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
