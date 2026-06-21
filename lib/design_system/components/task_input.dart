import 'package:flutter/material.dart';

import '../spacing.dart';
import '../typography.dart';
import 'tw_button.dart';

/// Input block for adding goals/tasks in TinyWins.
class TaskInput extends StatefulWidget {
  const TaskInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.label = 'Your goal',
    this.hint = 'Break this into tiny wins',
    this.actionLabel = 'Start Tiny Win',
    this.minLines = 3,
    this.maxLines = 6,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final String label;
  final String hint;
  final String actionLabel;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  void _submit() {
    final value = widget.controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.twText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.label, style: text.titleLarge),
        const TwGap.v(TwSpacing.sm),
        Text(widget.hint, style: text.bodyMedium),
        const TwGap.v(TwSpacing.md),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Task',
            hintText: 'Describe one thing you want to finish',
          ),
        ),
        const TwGap.v(TwSpacing.md),
        TwButton(
          label: widget.actionLabel,
          onPressed: widget.enabled ? _submit : null,
          icon: Icons.arrow_forward_rounded,
        ),
        const TwGap.v(TwSpacing.sm),
        Text(
          '${widget.controller.text.trim().length} chars',
          style: text.caption,
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
