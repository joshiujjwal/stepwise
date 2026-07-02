# CLAUDE.md — context for AI coding agents working on **stepwise**

This file (and `AGENTS.md`) let any agent pick up where the last left off. Keep it under ~200 lines; include
only what you can't infer from the code.

## What stepwise is
On-device AI task coordinator. The user describes a goal; an on-device **Gemma** model breaks it into
time-boxed micro-tasks the **user** executes. The AI only plans / re-plans. State advances on human approval
against acceptance criteria. Mobile (iOS + Android), Flutter. Single-user, offline, private.

Full spec: `docs/spec.md` (design decisions A–H are locked). Planner contract: `tool/coordinator/`.

## Commands (exact)
| Goal | Command |
|------|---------|
| Materialize iOS/Android (first time) | `flutter create .` |
| Install deps | `flutter pub get` |
| Run | `flutter run` |
| All tests | `flutter test` |
| One test | `flutter test test/state_machine_test.dart` |
| Analyze / lint | `dart analyze` |
| Format | `dart format .` |
| **Planner contract suite** (no Flutter; must stay GREEN) | `python3 tool/coordinator/validate_plan.py` |

## Directory map
- `lib/models/` — domain types + enums; `DurationBucket.fromMinutes` lives here.
- `lib/coordinator/` — `prompts.dart`, `planner.dart` (parse + validate + repair loop, `LlmClient`),
  `fake_llm_client.dart` + `demo_planner.dart` (offline/demo + hermetic tests), `gemma_llm_client.dart`
  (on-device adapter).
- `lib/state/` — `event_store.dart` (append-only log), `projections.dart` (pure read-models),
  `app_controller.dart` (`ChangeNotifier` orchestration), `app_scope.dart` (InheritedNotifier),
  `task_state_machine.dart` (transitions + guards), `persistence_store.dart` (durable-store
  interface + in-memory fake), `sqflite_persistence_store.dart` (sqflite backing).
- `lib/ui/` — one file per screen (`idea_screen`, `execute_screen`, `calendar_day_view`,
  `idea_progress_screen`, `trends_screen`) + `widgets.dart`.
- `tool/coordinator/` — `decomposition-contract.md` + `plan.schema.json` + `validate_plan.py` + `fixtures/` — **source of truth for planner output**.
- `docs/spec.md` — the v1 spec; `docs/wireframes/` — the screens (start at `7-flow-board`).

## Workflow (every session)
1. Read `TODO.md`; pick the next unchecked task in the lowest open phase.
2. **RUN THE TESTS FIRST:** `flutter test` and `python3 tool/coordinator/validate_plan.py`. Orient before editing.
3. **Red/green TDD:** write the failing test, confirm red, implement to green.
4. Review your diff. Commit with a clear message.
5. If you learned something non-obvious, append it to **Lessons** below.

## Non-obvious conventions & gotchas
- **Strictly human-executed v1.** The model never performs tasks; it returns a plan or clarifying questions.
  Do NOT add tool-execution to the coordinator.
- **Planner output is untrusted.** Always parse → validate (Dart port of `validate_plan.py`) → on error send
  ONE repair prompt → else a friendly fallback. Never render an unvalidated plan.
- **Keep Dart validation in lockstep with `tool/coordinator/validate_plan.py`.** The Python suite is the
  guard; `fixtures/` are reused by Dart tests.
- **Order is advisory.** `order_index` is a suggestion; any not-done task is "available". No hard deps.
- **Event log + projections.** Every mutation also appends an `EventRecord`; **trends** are pure
  projections of that log (`projections.dart`). Entity **state** (ideas/tasks) is held in memory and the
  authoritative copy in v1. Always append an event when you mutate, so trends/history stay correct.
- **Persistence (local, sqflite).** `AppController` takes an optional `PersistenceStore`; it
  write-throughs every mutation and `hydrate()`s the snapshot (ideas+tasks) + event log on startup,
  so data survives restarts. Persistence is **optional/null** in hermetic tests and the demo. `main.dart`
  guards both DB-open and `hydrate()` so a corrupt row degrades to in-memory instead of crashing startup.
  State is restored from a **snapshot**, not by *replaying* events (pure event-replay is still parked —
  event payloads don't carry full task detail). Any new model field must be added to `toMap`/`fromMap`.
- **Acceptance gate.** `awaiting_approval → done` requires ALL `acceptance_criteria` satisfied (checkbox default).
- **Models are huge + git-ignored.** Never commit `.task/.bin/.litertlm/.gguf`. The app loads them at runtime.
- **est_minutes** ∈ 5–60, multiple of 5; >60 must be split. `DurationBucket`: ≤15→15, ≤30→30, ≤45→45, else 60plus.

## Lessons
- **Model id must keep its file extension.** `GemmaModelService.modelId` must equal the basename
  flutter_gemma registers on install (e.g. `gemma3-1b-it.task`). Stripping the extension makes
  `isModelInstalled` miss the on-disk model, so the app re-downloads every launch and forces a manual
  "Download model" tap. (`lib/coordinator/model_service.dart`)
- **Persistence is snapshot + write-through, and must never block startup.** Restore is guarded in
  `main.dart` and `load()` skips corrupt rows per-row, so a bad blob degrades to in-memory rather than
  crash-looping. New model fields need `toMap`/`fromMap` updates or they silently won't persist.
- **On-device Gemma 3n E2B needs both a tolerant parser AND a multi-task prompt example.** The small
  model drops the top-level `action`, names the list `tasks`, nests each task under a `task` key, or
  emits criterion-shaped tasks — so `Coordinator._normalizeTaskItem`/`_firstTaskList` coerce those into
  the canonical shape (`test/coordinator_test.dart`). The planner/retasking prompts embed a **3-task**
  structural example (`_planStructureExample`) to stop the model collapsing to one task; the **repair**
  prompt must NOT contain that literal example or the model parrots the placeholder strings verbatim.
  Verify on-device with `flutter test integration_test/model_plan_test.dart -d <sim> --dart-define=GEMMA_MODEL_FILE=...`.

