import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import 'calendar_day_view.dart';
import 'idea_progress_screen.dart';
import 'widgets.dart';

/// Execute tab - actionable tasks with a duration filter and a List/Calendar
/// toggle. Wireframes: 1-do-next (list) and 5-calendar-day (calendar).
class ExecuteScreen extends StatefulWidget {
  const ExecuteScreen({super.key});

  @override
  State<ExecuteScreen> createState() => _ExecuteScreenState();
}

class _ExecuteScreenState extends State<ExecuteScreen> {
  DurationBucket? _bucket;
  bool _calendar = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execute'),
        actions: [
          IconButton(
            tooltip: _calendar ? 'List view' : 'Calendar view',
            icon: Icon(_calendar ? Icons.list : Icons.calendar_today),
            onPressed: () => setState(() => _calendar = !_calendar),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(),
          const Divider(height: 1),
          Expanded(
            child: _calendar
                ? CalendarDayView(controller: controller)
                : _list(controller),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final options = <(String, DurationBucket?)>[
      ('All', null),
      ('15 min', DurationBucket.m15),
      ('30 min', DurationBucket.m30),
      ('45 min', DurationBucket.m45),
      ('60+', DurationBucket.m60plus),
    ];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Time:', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, bucket) in options)
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
    );
  }

  Widget _list(AppController controller) {
    final tasks = controller.availableTasks(bucket: _bucket);
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nothing here. Add an idea on the Idea tab, or pick a different '
            'time filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final t = tasks[i];
        final idea = controller.ideas.firstWhere((x) => x.id == t.ideaId);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(t.title),
            subtitle: Text('${idea.type.name} - ${idea.title}'),
            leading: StatePill(t.state),
            trailing: DurationBadge(t.estMinutes),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IdeaProgressScreen(ideaId: t.ideaId),
              ),
            ),
          ),
        );
      },
    );
  }
}
