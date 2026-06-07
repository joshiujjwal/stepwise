---
applyTo: "lib/**/*.dart"
---
# Dart / Flutter conventions for `lib/`

- Null-safe Dart 3. Immutable models: `final` fields, `const` constructors where possible.
- Prefer `final` locals; never `var` for fields. No `print` (use `debugPrint` sparingly).
- Small, composable widgets; one screen per file; declarative `build` methods with early returns.
- Coordinator output is untrusted: **parse → validate → repair-once → fallback**. Mirror
  `tool/coordinator/validate_plan.py`; reuse `tool/coordinator/fixtures/` in tests.
- Mutations go through events (event-sourced); derive state/trends as projections — don't mutate task state
  without writing an `EventRecord`.
- `awaiting_approval → done` is guarded: all `acceptance_criteria` must be satisfied.
- Run `dart format .` and `dart analyze` before committing.
