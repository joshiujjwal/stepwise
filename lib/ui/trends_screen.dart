import 'package:flutter/material.dart';

/// Trends - throughput, current streak, estimate-vs-actual calibration, and a
/// friction map. All projected from the event log.
/// Wireframe: docs/wireframes/3-trends. Spec §6.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Your trends.\n\n'
            'TODO (Phase 3): throughput, streak, estimate-vs-actual calibration, '
            'and a friction map - all projected from the event log.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
