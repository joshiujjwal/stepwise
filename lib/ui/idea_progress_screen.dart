import 'package:flutter/material.dart';

/// Per-idea progress - ordered tasks with state, "step N of M", the acceptance
/// checklist, and re-tasked children. Opened from the Execute tab.
/// Wireframe: docs/wireframes/2-idea-progress. Spec §6.
class IdeaProgressScreen extends StatelessWidget {
  const IdeaProgressScreen({super.key, required this.ideaId});

  final String ideaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Idea progress')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Progress for idea $ideaId.\n\n'
            'TODO (Phase 1-2): step N of M, per-task state pills, acceptance '
            'checklist, and re-tasked children.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
