# AGENTS.md

Setup, conventions, and rules for AI agents and humans contributing to **stepwise**. Companion to `CLAUDE.md`.

## Setup
```bash
flutter create .                              # first time only: adds ios/ android/ etc.
flutter pub get
python3 tool/coordinator/validate_plan.py     # sanity check: planner contract suite (GREEN)
```

## Code style
- Dart 3, null-safe. Lints from `analysis_options.yaml` (flutter_lints + strict casts/inference).
- Immutable models: `final` fields, `const` constructors. Never `var` for fields.
- Declarative, composable widgets; one screen per file in `lib/ui/`. Use early returns; avoid deep nesting.
- `dart format .` before committing. No `print` (lint error) — use `debugPrint` sparingly.

## Testing (red/green TDD — required)
- Write the failing test first; confirm it fails; implement to green.
- `flutter test` for Dart; `python3 tool/coordinator/validate_plan.py` for the planner contract.
- Cover edge cases: invalid planner JSON, state-machine guards, duration bucketing, re-task limits.
- Reuse `tool/coordinator/fixtures/` in Dart planner tests. **Never delete existing tests.**

## Pull requests
- Small and focused; the title says what changed and why.
- **Required evidence:** paste `flutter test` + validator output; for UI add a screenshot/recording.
- Review AI-generated code **and** the PR description yourself — both can be confidently wrong.
- `dart analyze` clean and all suites green before requesting review.

## Boundaries
- Only touch files relevant to the task. Don't refactor unrelated code unasked.
- v1 is strictly human-executed: don't add agent task-execution. No external calendar sync. No multi-user.
- Don't commit model files. Don't add dependencies without justifying them in the PR.
