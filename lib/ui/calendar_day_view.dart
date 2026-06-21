import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'widgets.dart';

/// Day timeline where tasks render as duration-sized blocks (meeting-block
/// style), with an unscheduled tray. Wireframe: docs/wireframes/5-calendar-day.
class CalendarDayView extends StatelessWidget {
  const CalendarDayView({super.key, required this.controller});

  final AppController controller;

  static const int _startHour = 9;
  static const int _endHour = 18;
  static const double _ppm = 1.2; // pixels per minute

  @override
  Widget build(BuildContext context) {
    final available = controller.availableTasks();
    final scheduled = available.where((t) => t.scheduledStart != null).toList();
    final unscheduled =
        available.where((t) => t.scheduledStart == null).toList();
    final totalHeight = (_endHour - _startHour) * 60 * _ppm;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              for (int h = _startHour; h <= _endHour; h++)
                Positioned(
                  top: (h - _startHour) * 60 * _ppm,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$h:00',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
              for (final t in scheduled)
                Positioned(
                  top: (t.scheduledStart!.hour - _startHour) * 60 * _ppm +
                      t.scheduledStart!.minute * _ppm,
                  left: 60,
                  right: 0,
                  height: t.estMinutes * _ppm,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4, bottom: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: stateColor(context, t.state),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text('${t.title}  (${t.estMinutes}m)',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (unscheduled.isNotEmpty) ...[
          Text(
            'Unscheduled - tap to drop onto your day',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in unscheduled)
                ActionChip(
                  label: Text('${t.title} - ${t.estMinutes}m'),
                  onPressed: () => controller.scheduleTask(
                    t.id,
                    _nextSlot(scheduled.length),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  DateTime _nextSlot(int alreadyScheduled) {
    final now = DateTime.now();
    return DateTime(
        now.year, now.month, now.day, _startHour + alreadyScheduled);
  }
}
