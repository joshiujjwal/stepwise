# 2. Mobile + on-device Gemma; strictly-human-executed v1

Date: 2026-06-06
Status: Accepted

## Context
stepwise is a personal task coordinator and executive-function aid. Research (`docs/research-brief.md`)
found the market is burned by autonomous agents that act without oversight; reliability comes from
human-in-the-loop state machines. The product must be private and work offline. The full v1 spec
(`docs/spec.md`) locks design decisions A–H.

## Decision
- **Flutter (Dart)** — one codebase for iOS + Android.
- **On-device Gemma via `flutter_gemma`** (default **Gemma 3 1B IT**). No servers, no API keys, fully offline.
- **Strictly human-executed v1:** the coordinator only plans / clarifies / re-plans; the human executes and
  approves. State advances only when acceptance criteria are met.
- **Event-sourced state machine** (spec §1–§2); `order_index` is advisory (no hard dependencies).
- **Validated planner contract:** model output is parsed → validated (`tool/coordinator/`) → one repair
  retry → fallback before it ever reaches the UI.
- **Calendar/Day** view is an internal time-block timeline (no external calendar sync in v1).

## Consequences
- A small on-device model will sometimes emit imperfect JSON; the repair loop + reference validator are
  essential and are covered by tests.
- Out of scope for v1 (parking lot): agent task-execution, external calendar sync, multi-user.
- Model files are large and git-ignored; the app downloads/loads them at runtime.
- Dart is the implementation language (over the team's usual TypeScript) because `flutter_gemma` is the
  simplest batteries-included path to on-device Gemma on both platforms.
