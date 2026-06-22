import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'coordinator/fake_llm_client.dart';
import 'coordinator/model_service.dart';
import 'coordinator/planner.dart';
import 'coordinator/prompts.dart';
import 'coordinator/swappable_llm_client.dart';
import 'coordinator/todo_chunking_agent.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'state/engine_controller.dart';
import 'state/engine_scope.dart';
import 'theme/app_theme.dart';
import 'ui/execute_screen.dart';
import 'ui/idea_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/trends_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterGemma.initialize(
    huggingFaceToken: _huggingFaceTokenDefine(),
    maxDownloadRetries: _maxDownloadRetriesDefine(),
  );

  // The app starts on the offline demo planner so it is usable immediately.
  // When a model is configured (e.g. an Azure-hosted Gemma model via
  // GEMMA_MODEL_URL), [EngineController.initialize] downloads it and switches
  // the app to on-device Gemma, making Gemma the default engine.
  final llm = SwappableLlmClient(FakeLlmClient());
  final coordinator = Coordinator(llm);
  final controller = AppController(
    coordinator: coordinator,
    todoChunkingAgent: TodoChunkingAgent(
      coordinator: coordinator,
      systemPrompt: _optionalDefine('TODO_CHUNKING_SYSTEM_PROMPT') ??
          todoChunkingSystemPrompt,
    ),
  );
  final engine =
      EngineController(swappable: llm, modelService: _gemmaService());
  unawaited(engine.initialize());

  runApp(StepwiseApp(controller: controller, engine: engine));
}

/// Configure on-device Gemma from compile-time defines so URLs/tokens/paths are
/// never committed in source control.
///
/// One source is required:
///   --dart-define=GEMMA_MODEL_URL=https://.../gemma3-1b-it.task
///   --dart-define=GEMMA_MODEL_FILE=/absolute/path/to/model.task
///   --dart-define=GEMMA_MODEL_ASSET=assets/models/model.task
///
/// Optional:
///   --dart-define=GEMMA_MODEL_TOKEN=... (explicit auth token for a private model)
///   --dart-define=AZURE_BLOB_SAS_TOKEN=... (Azure Blob SAS token)
///   --dart-define=HF_TOKEN=hf_... (fallback for Hugging Face-hosted models)
///   --dart-define=GEMMA_MODEL_TYPE=gemmaIt|gemma4|deepSeek|qwen|qwen3|functionGemma|phi|general
///   --dart-define=GEMMA_MAX_TOKENS=2048
///   --dart-define=GEMMA_MAX_DOWNLOAD_RETRIES=2
///   --dart-define=TODO_CHUNKING_SYSTEM_PROMPT=...
ModelService? _gemmaService() {
  const modelFile = String.fromEnvironment('GEMMA_MODEL_FILE');
  const modelAsset = String.fromEnvironment('GEMMA_MODEL_ASSET');
  const modelUrl = String.fromEnvironment('GEMMA_MODEL_URL');
  if (modelFile.isEmpty && modelAsset.isEmpty && modelUrl.isEmpty) return null;

  final source = modelFile.isNotEmpty
      ? const GemmaModelSource.file(modelFile)
      : modelAsset.isNotEmpty
          ? const GemmaModelSource.asset(modelAsset)
          : GemmaModelSource.network(
              modelUrl,
              token: resolveModelAccessToken(
                modelToken: _optionalDefine('GEMMA_MODEL_TOKEN'),
                azureBlobSasToken: _optionalDefine('AZURE_BLOB_SAS_TOKEN'),
                huggingFaceToken: _huggingFaceTokenDefine(),
              ),
            );

  final modelType = _modelTypeFromName(_optionalDefine('GEMMA_MODEL_TYPE')) ??
      _inferModelTypeFromSource(source.location) ??
      ModelType.gemmaIt;
  final maxTokens =
      int.tryParse(_optionalDefine('GEMMA_MAX_TOKENS') ?? '') ?? 2048;

  return GemmaModelService(
    source: source,
    modelType: modelType,
    maxTokens: maxTokens,
  );
}

String? readConfigValue(
  String key, {
  Map<String, String>? environment,
}) {
  final defineValue = String.fromEnvironment(key);
  if (defineValue.isNotEmpty) return defineValue;
  final envValue = (environment ?? Platform.environment)[key];
  if (envValue != null && envValue.isNotEmpty) return envValue;
  return null;
}

String? _huggingFaceTokenDefine() =>
    _optionalDefine('HF_TOKEN') ?? _optionalDefine('HUGGINGFACE_TOKEN');

int _maxDownloadRetriesDefine() {
  final configured =
      int.tryParse(_optionalDefine('GEMMA_MAX_DOWNLOAD_RETRIES') ?? '');
  if (configured == null || configured < 1) return 2;
  return configured;
}

String? _optionalDefine(String key) => readConfigValue(key);

ModelType? _modelTypeFromName(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  return switch (normalized) {
    'modeltypegemmait' || 'gemmait' => ModelType.gemmaIt,
    'modeltypegemma4' || 'gemma4' => ModelType.gemma4,
    'modeltypedeepseek' || 'deepseek' => ModelType.deepSeek,
    'modeltypeqwen' || 'qwen' => ModelType.qwen,
    'modeltypeqwen3' || 'qwen3' => ModelType.qwen3,
    'modeltypefunctiongemma' || 'functiongemma' => ModelType.functionGemma,
    'modeltypephi' || 'phi' => ModelType.phi,
    'modeltypegeneral' || 'general' => ModelType.general,
    _ => null,
  };
}

ModelType? _inferModelTypeFromSource(String sourceLocation) {
  final s = sourceLocation.toLowerCase();
  if (s.contains('gemma-4') || s.contains('gemma4')) return ModelType.gemma4;
  if (s.contains('qwen3')) return ModelType.qwen3;
  if (s.contains('qwen')) return ModelType.qwen;
  if (s.contains('deepseek')) return ModelType.deepSeek;
  if (s.contains('functiongemma')) return ModelType.functionGemma;
  if (s.contains('phi')) return ModelType.phi;
  if (s.contains('gemma')) return ModelType.gemmaIt;
  return null;
}

class StepwiseApp extends StatelessWidget {
  const StepwiseApp({
    super.key,
    required this.controller,
    required this.engine,
  });

  final AppController controller;
  final EngineController engine;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: EngineScope(
        controller: engine,
        child: MaterialApp(
          title: 'StepWins',
          theme: buildStepwiseTheme(),
          darkTheme: buildStepwiseDarkTheme(),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: const HomeShell(),
        ),
      ),
    );
  }
}

/// Idea | Execute | Trends | Settings (spec section 11 + engine management).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    IdeaScreen(),
    ExecuteScreen(),
    TrendsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Idea',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'Execute',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
