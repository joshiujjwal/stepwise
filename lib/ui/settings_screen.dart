import 'package:flutter/material.dart';

import '../coordinator/model_service.dart';
import '../state/engine_controller.dart';
import '../state/engine_scope.dart';
import '../theme/tokens.dart';
import 'widgets.dart';

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
    final space = context.space;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(space.lg),
        children: [
          const ScreenHeader(
            title: 'Settings',
            subtitle:
                'Tune your planner engine and privacy defaults to keep earning wins.',
          ),
          SizedBox(height: space.lg),
          Card(
            child: ListTile(
              leading: Icon(Icons.memory, color: context.colors.primary),
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
          SizedBox(height: space.md),
          if (!engine.gemmaAvailable)
            Card(
              child: Padding(
                padding: EdgeInsets.all(space.lg),
                child: Text(
                  'On-device Gemma is not configured for this build. StepWins is '
                  'running its offline demo planner. To enable Gemma, run with '
                  '--dart-define=GEMMA_MODEL_URL=... or GEMMA_MODEL_FILE=... '
                  'and optionally --dart-define=GEMMA_MODEL_TOKEN=... or '
                  'AZURE_BLOB_SAS_TOKEN=... (see lib/main.dart).',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
            )
          else
            _gemmaCard(engine),
          SizedBox(height: space.md),
          _privacyNote(),
        ],
      ),
    );
  }

  Widget _gemmaCard(EngineController engine) {
    final model = engine.model;
    final space = context.space;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On-device Gemma', style: context.texts.titleMedium),
            SizedBox(height: space.xs),
            Text(
              _statusText(model),
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            SizedBox(height: space.md),
            if (model.phase == ModelPhase.downloading) ...[
              LinearProgressIndicator(value: model.progress),
              if (_downloadDetail(model).isNotEmpty) ...[
                SizedBox(height: space.xs),
                Text(
                  _downloadDetail(model),
                  style: context.texts.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ] else
              Wrap(
                spacing: space.sm,
                runSpacing: space.sm,
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
              SizedBox(height: space.sm),
              Text(
                model.error!,
                style: context.texts.bodySmall
                    ?.copyWith(color: context.colors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _privacyNote() {
    final space = context.space;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(space.lg),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: context.colors.primary),
            SizedBox(width: space.sm),
            Expanded(
              child: Text(
                'Everything runs on your device. Your ideas and tasks never '
                'leave your phone.',
                style: context.texts.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
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

  /// A speedtest-style line for the active download: live MB/s and, when the
  /// total size is known, the downloaded/total sizes. Empty when there is
  /// nothing meaningful to show yet (e.g. before the first byte-rate sample).
  String _downloadDetail(ModelState model) {
    final parts = <String>[
      formatDownloadSpeed(model.bytesPerSecond),
      if (model.totalBytes != null)
        '${formatBytes(model.downloadedBytes)} / ${formatBytes(model.totalBytes)}',
    ].where((p) => p.isNotEmpty).toList();
    return parts.join('  •  ');
  }
}
