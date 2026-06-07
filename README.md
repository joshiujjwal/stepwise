# stepwise

[![CI](https://github.com/joshiujjwal/stepwise/actions/workflows/ci.yml/badge.svg)](https://github.com/joshiujjwal/stepwise/actions/workflows/ci.yml)

> 🚧 **Status: Early development (design complete, scaffolding stage).**

**On-device AI task coordinator.** You describe a goal in plain words; an on-device **Gemma** model breaks
it into **time-boxed, doable micro-tasks**. You do them one at a time, and each step only advances when you
confirm its acceptance criteria. Get stuck and the coordinator **re-breaks** that step into smaller ones.
A focus timer, a calendar/day view, and trends keep you moving.

Built for personal use and executive-function support (think: a smarter, stateful Goblin Tools). **Strictly
human-executed** in v1 — the AI plans and re-plans; you execute and approve. Everything runs **on-device**:
no servers, no API keys, no data leaves your phone.

## Tech stack
- **Flutter** (Dart) — one codebase for **iOS + Android**
- **[flutter_gemma](https://pub.dev/packages/flutter_gemma)** — on-device Gemma (default: **Gemma 3 1B IT**)
- Event-sourced local store (sqflite — pinned in Phase 0)
- Coordinator contract validated by a Python reference validator (`tool/coordinator/`)

## Getting started
> Requires the Flutter SDK (stable channel), plus Xcode (iOS) and the Android SDK.

```bash
# 1. Materialize the iOS/Android platform folders into this repo
flutter create .

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or simulator
flutter run

# 4. Tests + static analysis
flutter test
dart analyze

# 5. Validate the planner contract (no Flutter needed — suite is GREEN)
python3 tool/coordinator/validate_plan.py
```

**On-device model:** download a Gemma model (e.g. Gemma 3 1B `.task`/LiteRT) per the
[flutter_gemma](https://pub.dev/packages/flutter_gemma) instructions. Models are large and **git-ignored** —
the app fetches/loads them at first run (see Phase 0 in [`TODO.md`](TODO.md)).

> **Run it now (demo mode):** the app ships wired to an offline `FakeLlmClient`, so `flutter run` works
> with **no model** — full capture → plan → execute → approve → trends flow, deterministic. Swap in
> `GemmaLlmClient` (`lib/coordinator/gemma_llm_client.dart`) once a model is installed to use real
> on-device Gemma.

## Project structure
```
stepwise/
├── lib/
│   ├── models/        # Idea, MicroTask, AcceptanceCriterion, EventRecord, enums
│   ├── coordinator/   # prompts + PlannerResponse parse/validate + repair loop
│   ├── state/         # micro-task state machine + guards
│   ├── ui/            # Idea, Execute (list/calendar), Idea progress, Trends
│   └── theme/
├── test/              # mirrors lib/ (red/green TDD)
├── docs/
│   ├── spec.md                  # full v1 spec (decisions A–H locked)
│   ├── research-brief.md        # market + technical + discourse research
│   ├── wireframes/              # Excalidraw screens + flow board (start: 7-flow-board)
│   └── adr/                     # architecture decision records
├── tool/coordinator/  # decomposition-contract.md, plan.schema.json, validate_plan.py, fixtures/
├── .github/           # copilot-instructions, path instructions, skills
├── CLAUDE.md  AGENTS.md         # agent context
└── pubspec.yaml
```

## How it works (the core loop)
1. **Idea** — describe a goal; the coordinator may ask 1–2 clarifying questions, then streams a proposed plan.
2. **Confirm** — you approve/revise the plan; micro-tasks are created.
3. **Execute** — pick a task that fits your time (15/30/45 min), optionally run the focus timer.
4. **Approve** — mark acceptance criteria done (checkbox by default; or url/file/note evidence) → `done`.
5. **Re-task** — stuck or too big? The coordinator breaks that one task into finer steps.

See [`docs/spec.md`](docs/spec.md) and the planner contract in
[`tool/coordinator/decomposition-contract.md`](tool/coordinator/decomposition-contract.md).

## Contributing
- **Red/green TDD:** write the failing test first, confirm it fails, then implement until green.
- **Evidence in PRs:** include test output and (for UI) a screenshot/recording. Review AI-written code and
  PR descriptions yourself — never land unreviewed output.
- **Small, focused PRs.** Never remove existing tests. Run `dart analyze`, `flutter test`, and
  `python3 tool/coordinator/validate_plan.py` before pushing.
- Keep the Dart planner validation in sync with `tool/coordinator/validate_plan.py` (the fixtures are the guard).
