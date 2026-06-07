# stepwise — Task Breakdown

Evidence-gated phases. Don't advance a phase until its tasks have passing tests and a human review.

## How to use this file
Per task: write the test FIRST (red) → implement to green → review the diff → commit → if you learned
something non-obvious, append it to **Lessons learned**.

Status keys: ⬜ not started · 🟦 in progress · ✅ done

---

## Phase 0: Foundation
- [ ] `flutter create .` to materialize iOS + Android platform folders ⬜ (run on a dev machine)
- [x] `flutter pub get`; `flutter_gemma` resolves ✅
- [x] Linter + formatter (`analysis_options.yaml`); `dart analyze` clean ✅
- [x] Test framework + first smoke test (`test/app_smoke_test.dart`) ✅
- [x] CI (GitHub Actions): validator + analyze + test ✅
- [ ] On-device model setup screen: download + load Gemma via flutter_gemma ⬜ (device)
- [x] Review AI config files ✅

## Phase 1: Core loop — Idea → plan → Execute
- [x] Domain models + enums (`lib/models/models.dart`) ✅
- [x] `DurationBucket.fromMinutes` ✅
- [x] Micro-task state machine + guards ✅
- [x] Dart planner validation (mirrors `validate_plan.py`) + reuse fixtures ✅
- [x] `flutter_gemma` behind `LlmClient` (`GemmaLlmClient`) + JSON repair loop ✅
- [x] Idea tab: conversational capture (clarify → plan → confirm) ✅
- [x] Execute tab (list): Do-Next + 15/30/45 filter ✅
- [ ] Manual end-to-end test with a real Gemma model (record evidence) ⬜ (device)

## Phase 2: Secondary features
- [x] Acceptance gate UI (checkbox/url/file/note; approve gated) ✅
- [x] Focus timer → `focus_seconds` ✅
- [x] Calendar/day view (duration-sized blocks + unscheduled tray) ✅
- [x] Re-tasking (blocked + proactive break-down → children) ✅
- [x] Event-sourced store (in-memory) + projections ✅
- [ ] sqflite write-through persistence ⬜ (device; parking lot)

## Phase 3: Polish & harden
- [x] Trends dashboard (throughput, streak, completion, calibration, friction) ✅
- [x] Empty states on Execute ✅
- [ ] Onboarding / model-download flow ⬜
- [ ] Performance + memory on low-end devices; 1B vs 270M default ⬜
- [ ] Accessibility + dark mode pass ⬜

## Phase 4: Ship
- [ ] App icon + splash; store metadata; "100% on-device / private" ⬜
- [ ] iOS TestFlight + Android internal testing ⬜
- [ ] Crash/feedback capture ⬜

---

## Parking lot 🅿️
- sqflite persistence; real Gemma model download/run (both device)
- External calendar sync, agent-executed tasks, multi-user — out of scope for v1
- On-device RAG over past ideas (flutter_gemma supports it)

## Lessons learned 📝
- **Dart 3 formatter vs `require_trailing_commas`:** the lint flags commas the "tall" formatter itself
  produces on wrapped calls. Removed the lint; `dart format` is the source of truth.
- **`.gitignore` ordering:** a bare `models/` rule also matched `lib/models/`. Scope app-model ignores to
  `/models/` and `*.task`/`*.bin`/`*.litertlm`/`*.gguf`.
- **Widget tests:** `find.text('15 min')` collides between a filter chip and duration badges — use
  `find.widgetWithText(ChoiceChip, '15 min')`.
- **Hermetic AI tests:** `FakeLlmClient` returns canned JSON through the REAL parse/validate/repair
  pipeline, so the coordinator is tested without a model. Keep it in sync with `validate_plan.py`.
- **CI catches what local misses:** run `flutter analyze` AFTER `dart format`, not before.
