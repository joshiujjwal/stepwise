import 'package:flutter/material.dart';

/// Idea tab - conversational capture (clarify -> streamed plan -> Confirm/Revise).
/// Wireframe: docs/wireframes/6-idea-capture. Spec §11 and §4.
class IdeaScreen extends StatelessWidget {
  const IdeaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Idea')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Describe a goal in your own words.\n\n'
            'TODO (Phase 1): conversational capture wired to the on-device Coordinator '
            '(0-2 clarifying questions, then a streamed plan to confirm).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
