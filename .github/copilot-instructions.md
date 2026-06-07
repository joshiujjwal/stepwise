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

## Testing
- Red/green TDD: failing test first. `flutter test` + `python3 tool/coordinator/validate_plan.py`.
- Reuse `tool/coordinator/fixtures/` for planner tests. Never remove tests.

## Boundaries
- Only modify files relevant to the task. Don't refactor unrelated code or "clean up" unasked.
- Don't add agent task-execution (out of scope v1). Don't commit model files. Don't add external calendar sync.
- Don't introduce new dependencies without noting why in the PR.
