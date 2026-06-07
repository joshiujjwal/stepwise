# stepwise — Task Breakdown

The build plan, as **evidence-gated** phases. Don't advance a phase until its tasks have passing tests and a
human review.

## How to use this file
Per task:
1. Write the test(s) FIRST (red). Confirm they fail.
2. Implement until they pass (green).
3. Review the diff yourself.
4. Commit with a descriptive message.
5. If you learned something non-obvious, update `CLAUDE.md` / `AGENTS.md` (compound loop).

Status keys: ⬜ not started · 🟦 in progress · ✅ done

---

## Phase 0: Foundation ⬜
- [ ] `flutter create .` to materialize iOS + Android platform folders into this repo
- [ ] `flutter pub get`; confirm `flutter_gemma` resolves
- [ ] `dart analyze` clean against `analysis_options.yaml`
- [ ] First widget smoke test green (`flutter test`)
- [ ] CI (GitHub Actions): `flutter analyze` + `flutter test` + `python3 tool/coordinator/validate_plan.py`
- [ ] On-device model setup screen: download + load Gemma 3 1B via flutter_gemma; handle progress/errors
- [ ] Review the AI config files (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`)

## Phase 1: Core loop — Idea → plan → Execute ⬜
- [ ] Domain models + enums (`Idea`, `MicroTask`, `AcceptanceCriterion`, `EventRecord`) — **tests first**
- [ ] `DurationBucket.fromMinutes` (15/30/45/60+) — red→green (mirror the Python rule)
- [ ] Micro-task **state machine** + guards (`awaiting_approval→done` needs all criteria) — tests first
- [ ] Port `validate_plan` rules to Dart (`lib/coordinator/planner.dart`); reuse `tool/coordinator/fixtures/`
- [ ] Wire `flutter_gemma` behind an `LlmClient`; planning prompt; **JSON repair loop** (validate→1 retry→fallback)
- [ ] **Idea** tab: conversational capture (clarify → streamed plan → Confirm/Revise) — wireframe `6-idea-capture`
- [ ] **Execute** tab (list): Do-Next with the 15/30/45 duration filter — wireframe `1-do-next`
- [ ] Manual end-to-end test with a real Gemma model; capture a screen recording as evidence

## Phase 2: Secondary features ⬜
- [ ] Acceptance gate UI: per-criterion checkbox (default) + url/file/note; `approve → done`
- [ ] **Focus timer** (start/stop/pause) emitting `timer_*` events; accumulate `focus_seconds`
- [ ] **Calendar / Day** view: tasks as duration-sized time blocks + unscheduled tray — wireframe `5-calendar-day`
- [ ] **Re-tasking**: `blocked` (+reason) and proactive "break this down" → re-task prompt → child tasks
- [ ] Event-sourced store (sqflite) + projections (task state, progress, trends inputs)

## Phase 3: Polish & harden ⬜
- [ ] **Trends** dashboard: throughput, streak, estimate-vs-actual calibration, friction map — wireframe `3-trends`
- [ ] Onboarding + empty states; executive-function niceties (show next 1–3 only; celebrate completion)
- [ ] Performance: model load time + memory on low-end devices; decide 1B vs 270M default
- [ ] Accessibility + dark mode pass

## Phase 4: Ship ⬜
- [ ] App icon + splash; store metadata; "100% on-device / private" note
- [ ] iOS TestFlight + Android internal testing builds
- [ ] Crash/feedback capture

---

## Parking lot 🅿️
- External calendar sync (Google/Outlook) — explicitly out of scope for v1
- Agent-executed tasks (hybrid) — v2
- Multi-user / shared ideas — v2
- On-device RAG over past ideas (flutter_gemma supports it)

## Lessons learned 📝
- (Append non-obvious findings here as you build; feed the best ones back into `CLAUDE.md`/`AGENTS.md`.)
