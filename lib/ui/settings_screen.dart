import 'package:flutter/material.dart';

import '../coordinator/model_service.dart';
import '../state/engine_controller.dart';
import '../state/engine_scope.dart';

/// Settings - manage the AI engine. The app runs offline in demo mode by
/// default; on-device Gemma can be downloaded and enabled here (spec / ADR 0002).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = EngineScope.of(context);
      if (engine.model.phase != ModelPhase.downloading) {
        engine.refreshStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = EngineScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tune your planner engine and privacy defaults to keep earning wins.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('AI engine'),
              subtitle: Text(engine.engineStatusLabel),
              trailing: engine.model.phase == ModelPhase.downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (!engine.gemmaAvailable)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'On-device Gemma is not configured for this build. StepWins is '
                  'running its offline demo planner. To enable Gemma, run with '
                  '--dart-define=GEMMA_MODEL_URL=... or GEMMA_MODEL_FILE=... '
                  'and optionally --dart-define=GEMMA_MODEL_TOKEN=... or '
                  'AZURE_BLOB_SAS_TOKEN=... (see lib/main.dart).',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            _gemmaCard(engine),
          const SizedBox(height: 8),
          _privacyNote(),
        ],
      ),
    );
  }

  Widget _gemmaCard(EngineController engine) {
    final model = engine.model;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('On-device Gemma',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_statusText(model),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (model.phase == ModelPhase.downloading)
              LinearProgressIndicator(value: model.progress)
            else
              Wrap(
                spacing: 8,
                children: [
                  if (model.phase != ModelPhase.ready)
                    FilledButton.icon(
                      onPressed: engine.downloadModel,
                      icon: const Icon(Icons.download),
                      label: const Text('Download model'),
                    ),
                  if (model.phase == ModelPhase.ready &&
                      engine.mode == EngineMode.demo)
                    FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await engine.enableGemma();
                        if (!ok) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Could not start Gemma; staying on demo.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Use on-device Gemma'),
                    ),
                  if (engine.mode == EngineMode.gemma)
                    OutlinedButton(
                      onPressed: engine.useDemo,
                      child: const Text('Switch to demo'),
                    ),
                ],
              ),
            if (model.phase == ModelPhase.error && model.error != null) ...[
              const SizedBox(height: 8),
              Text(model.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _privacyNote() {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Everything runs on your device. Your ideas and tasks never '
                'leave your phone.',
                style: TextStyle(color: onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(ModelState model) => switch (model.phase) {
        ModelPhase.unknown => 'Checking...',
        ModelPhase.notInstalled => 'Not downloaded yet (~1 GB, one time).',
        ModelPhase.downloading =>
          'Downloading... ${(model.progress * 100).round()}%',
        ModelPhase.ready => 'Installed and ready.',
        ModelPhase.error => 'Something went wrong.',
      };
}
