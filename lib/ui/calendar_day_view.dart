import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
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
    final space = context.space;
    final available = controller.availableTasks();
    final scheduled = available.where((t) => t.scheduledStart != null).toList();
    final unscheduled =
        available.where((t) => t.scheduledStart == null).toList();
    final totalHeight = (_endHour - _startHour) * 60 * _ppm;

    return ListView(
      padding: EdgeInsets.all(space.md),
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
                          style: context.texts.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
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
                    margin: EdgeInsets.only(right: space.xs, bottom: 2),
                    padding: EdgeInsets.all(space.xs + 2),
                    decoration: BoxDecoration(
                      color: stateColor(context, t.state),
                      borderRadius: context.radius.smAll,
                      border: Border.all(color: context.colors.outlineVariant),
                    ),
                    child: Text(
                      '${t.title}  (${t.estMinutes}m)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: stateOnColor(context, t.state),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: space.md),
        if (unscheduled.isNotEmpty) ...[
          Text(
            'Unscheduled - tap to drop onto your day',
            style: context.texts.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          SizedBox(height: space.sm),
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
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
