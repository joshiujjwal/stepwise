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
  `task_state_machine.dart` (transitions + guards).
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
- **Event-sourced.** Mutations are events; task state + trends are projections. Don't mutate state without
  writing an event.
- **Acceptance gate.** `awaiting_approval → done` requires ALL `acceptance_criteria` satisfied (checkbox default).
- **Models are huge + git-ignored.** Never commit `.task/.bin/.litertlm/.gguf`. The app loads them at runtime.
- **est_minutes** ∈ 5–60, multiple of 5; >60 must be split. `DurationBucket`: ≤15→15, ≤30→30, ≤45→45, else 60plus.

## Lessons
- (Append discoveries here as you build.)
