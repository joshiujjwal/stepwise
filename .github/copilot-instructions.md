# GitHub Copilot — stepwise

## Stack
Flutter (Dart 3) mobile app for **iOS + Android**. On-device **Gemma** via `flutter_gemma`. Event-sourced
local store. Single-user, offline, private. **Strictly human-executed v1** — the AI plans; the human
executes and approves. See `docs/spec.md` and `tool/coordinator/decomposition-contract.md`.

## Conventions
- Null-safe Dart 3; immutable models (`final` fields, `const` constructors); never `var` for fields; no `print`.
- Declarative Flutter widgets; one screen per file in `lib/ui/`, matching `docs/wireframes/`.
- Coordinator: **parse → validate → ONE repair retry → fallback**. Keep Dart validation in sync with
  `tool/coordinator/validate_plan.py`.
- `order_index` is advisory (no hard deps). Every mutation also appends an event; **trends** are
  projections of the event log, while entity **state** is the in-memory source of truth in v1.
- `est_minutes` 5–60, multiple of 5; `DurationBucket` ≤15/≤30/≤45/else 60plus.

## Running the app
- List/boot a simulator first: `xcrun simctl list devices booted` (or `flutter devices`), then `flutter run -d <device-id>`.
- The app needs a Gemma model at runtime, injected via dart-defines. On simulator/dev use a local file:
  `flutter run -d <id> --dart-define=GEMMA_MODEL_FILE=/Volumes/Stuff/code/stepwise/model/<model>.litertlm`.
  Alternatives: `GEMMA_MODEL_ASSET` (bundled) or `GEMMA_MODEL_URL` (runtime download).
- On-device integration test: `flutter test integration_test/model_plan_test.dart -d <id> --dart-define=GEMMA_MODEL_FILE=...`.

## Model loading gotchas (rediscovered the hard way — read first)
- `createSession` **temperature must be > 0** (e.g. 0.3, topK 40, topP 0.9). `0.0` breaks the LiteRT FFI
  sampler and emits `<pad>`/garbage.
- `.litertlm` models require `fileType: ModelFileType.litertlm`; the default `.task` routes to MediaPipe and fails to load on iOS.
- `GemmaModelService.modelId` must keep the file extension (e.g. `gemma3-1b-it.task`); stripping it makes
  `isModelInstalled` miss the on-disk model and re-download every launch.
- Azure Blob SAS must be appended to the URL query (`buildModelNetworkSource`), NOT passed as the flutter_gemma
  token (sent as `******`, which Azure rejects with 403).
- More detail in `CLAUDE.md` → Lessons.

## Release builds & model hosting
- Release/IPA builds go through `build-script.bash`, which injects the CDN model defines — simulator uses
  `GEMMA_MODEL_FILE`, but IPA/TestFlight needs `GEMMA_MODEL_URL` (runtime download); a local file path won't ship.
- Infra scripts live in `tool/infra/` (`setup_frontdoor.sh`). Azure Front Door config changes take ~20 min to
  propagate (up to 40 for back-to-back); don't recreate/toggle to force it — a fresh 404 is usually propagation.

## Testing
- Red/green TDD: failing test first. `flutter test` + `python3 tool/coordinator/validate_plan.py`.
- Reuse `tool/coordinator/fixtures/` for planner tests. Never remove tests.
- After changes to the model-loading or IPA/release path, run the suite **and** a build (`build-script.bash`),
  not just `flutter test`.

## Boundaries
- Only modify files relevant to the task. Don't refactor unrelated code or "clean up" unasked.
- Don't add agent task-execution (out of scope v1). Don't commit model files. Don't add external calendar sync.
- Don't introduce new dependencies without noting why in the PR.
- Commit hygiene: stage only task-relevant files. Never commit `feedback.txt`, `gemma.local.json` (or other
  `*.local.json`), or model blobs (`*.litertlm`/`.task`/`.bin`/`.gguf`); leave pre-existing unrelated changes uncommitted.
