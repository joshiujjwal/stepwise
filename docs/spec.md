# v1 Spec (Draft) — Personal Agentic Micro-Task Coordinator

_Stack-agnostic. Strictly human-executed. Single-user / executive-function focus. Date: 2026-06-06._

## 0. One-liner
Enter a messy goal → the coordinator breaks it into **time-boxed, concrete micro-tasks** → you do them
one at a time → each advances only when you **confirm its acceptance criteria with evidence** → get
stuck and the coordinator **re-breaks** that step into smaller ones → see progress and trends.

## 1. Core objects (data model)

### Idea (a.k.a. Goal)
`{ id, title, raw_input, type, status, created_at, plan_version }`
- `type`: a small fixed list (`tax | trip | errand | admin | project | other`), **auto-suggested** from
  the idea text by the coordinator and **editable** by the user → seeds a type-specific plan.
- `status`: `planning → active → done`, plus `stalled` (has blocked leaf tasks).

### MicroTask
`{ id, idea_id, parent_task_id?, title, description, est_minutes, duration_bucket,
   order_index, scheduled_start?, state, created_at, plan_version }`
- `parent_task_id?`: set when this task was produced by **re-tasking** a stuck task.
- `duration_bucket`: derived → `15 | 30 | 45 | 60plus`.
- `scheduled_start?`: optional planned time for the **Calendar / Day** view (§6); tasks may be unscheduled.
- `order_index`: **suggested** sequence only — advisory, **non-blocking**. Any not-done task can be
  started at any time (you may do task n+1 before n). No hard dependencies in v1.
- `focus_seconds` (derived): total **focused** time from the optional timer (sum of timer sessions);
  `0` if the user never ran it. Powers estimate-vs-actual calibration.

### AcceptanceCriterion ("definition of done")
`{ id, microtask_id, text, evidence_type, evidence_value?, satisfied }`
- `evidence_type`: `checkbox` (default) `| note | url | file` (e.g. "URL of submitted form", "photo of documents").

### Event (event-sourced — powers progress, trends, history)
`{ id, idea_id, microtask_id?, type, from_state?, to_state?, actor, payload, ts }`
- `actor`: `user | coordinator`.
- `type`: `idea_created | plan_generated | plan_proposed | plan_confirmed | task_started | task_submitted |
   task_approved | task_blocked | task_retasked | estimate_overridden | criterion_satisfied |
   timer_started | timer_paused | timer_resumed | timer_stopped | …`

> Everything derivable (progress %, trends, streaks, calibration) is computed from the Event log.
> MicroTask.state is a cached projection of events.

## 2. Micro-task state machine

```
        ┌──────────────────────────── re-tasked (superseded) ◄─┐
        │                                                       │ (children created)
   todo ──► in_progress ──► awaiting_approval ──► done          │
     ▲           │                  │                           │
     │           └──────────────────┘ (rejected: criteria not met)
     │                                                          │
     └────────────── blocked ───────────────────────────────────┘
                       ▲ (stuck)        (coordinator re-breaks)
```

Transitions + guards:
| From | To | Trigger | Guard |
|---|---|---|---|
| todo | in_progress | user starts | — (any task can start anytime; order is advisory) |
| in_progress | awaiting_approval | user submits + provides evidence | — |
| awaiting_approval | done | user confirms | **all acceptance criteria `satisfied`** |
| awaiting_approval | in_progress | criteria not actually met | — |
| any (todo/in_progress) | blocked | user flags "stuck" + reason | — |
| any (todo/in_progress) | re-tasked | user "break this down" (proactive) → coordinator decomposes | — |
| blocked | re-tasked | coordinator decomposes into finer children | — |

**Idea status** is derived: `planning` (no plan yet) → `active` → `stalled` (≥1 blocked leaf) →
`done` (all leaf tasks `done`).

## 3. The approval gate in single-user mode (key design decision)
There's no second person to approve, so the gate's value is **structured self-verification** (this is the
antidote to the "agent silently did the wrong thing" failure the research surfaced):
- On submit, the coordinator generates a short **verification challenge** from the acceptance criteria,
  e.g. _"Confirm you actually submitted the return — paste the confirmation number or check the box."_
- `done` is only reachable when each criterion is marked `satisfied` (with its evidence).
- This keeps friction meaningful without inventing a fake approver.
- ✅ **DECIDED:** per-criterion **checkbox by default**, with `url/file/note` optional when the user
  wants stronger proof. `done` requires every criterion marked `satisfied`.

## 4. Decomposition contract (the coordinator's core job)
_Full prompts + JSON Schema + a proven validator live in `tool/coordinator/`
(`decomposition-contract.md`, `plan.schema.json`, `validate_plan.py` — test-suite GREEN)._
Input: `{ idea.title, idea.raw_input, idea.type? }`
Output (strict JSON): ordered micro-tasks:
```json
{
  "micro_tasks": [
    {
      "title": "Gather all tax documents",
      "description": "Collect W-2s, 1099s, deduction receipts into one folder.",
      "est_minutes": 30,
      "acceptance_criteria": [
        { "text": "All W-2s and 1099s in one folder", "evidence_type": "checkbox" }
      ]
    }
  ]
}
```
**Conversational flow:** idea → coordinator asks **0–2 clarifying questions** if the idea is ambiguous →
proposes the plan (streamed, `plan_proposed`) → user **confirms** (`plan_confirmed`) or requests changes
(`plan_revised`) → micro-tasks are created.

Planner constraints (enforced in the prompt + validated on parse):
- Each micro-task **doable in one sitting** → `est_minutes ≤ 60` (else split it).
- Each has a **concrete, checkable** definition of done (no vague "research stuff").
- Tasks have a **suggested order** (`order_index`) that is advisory, **not** enforced — the user may do a
  later task first. No hard dependencies in v1.
- Prefer **5–12 micro-tasks** for a typical idea; offer "break down further" on demand.

## 5. Duration handling (req 3)
- LLM estimates `est_minutes` per task at plan time → bucket to `15 | 30 | 45 | 60plus`.
- User can **override** the estimate (event: `estimate_overridden`).
- **Optional focus timer** (start/stop/pause) per task records *focused* time (via `timer_*` events) →
  accurate actual-vs-estimate calibration, and doubles as a focus aid (Pomodoro-friendly). Use is
  optional; calibration is computed only for tasks where the timer ran.
- The **"What can I do in 15 min?"** filter is a first-class, front-and-center control (executive-function UX).

## 6. Views (req 4 & 5)
_Wireframes (Excalidraw): `docs/wireframes/` → **`7-flow-board`** (all screens + nav arrows, start here),
`6-idea-capture` (Idea tab), `1-do-next` & `5-calendar-day` (Execute: list & calendar), `2-idea-progress`,
`3-trends`, `4-state-machine`. PNG previews alongside each. Regenerate via `generate_wireframes.py`._
- **Do Next** (home): **actionable = any not-done task** (order is advisory), filterable by duration;
  sorted by suggested `order_index`, but you can pick any — including doing task n+1 before n. Default
  surfaces the **next 1–3 suggested steps** to avoid overwhelm.
- **Idea progress**: ordered tasks with state, "step 3 of 8", % complete, current acceptance checklist.
- **Calendar / Day** (the sketch's "Calendar UI"): a day timeline where micro-tasks render as **time blocks
  sized by duration** (meeting-block style); place tasks by `scheduled_start`, duration chips filter what fits,
  an "unscheduled" tray holds the rest. List ⇄ Calendar toggle inside the Execute tab.
- **Trends dashboard** (from Event log):
  - Throughput: tasks done / day / week; current streak.
  - Estimate calibration: estimated vs **actual focused time** (from the optional timer; tasks without timer use are excluded).
  - Friction map: where you get `blocked` / `re-tasked` most.
  - Time invested per idea; completion rate.

## 7. Re-tasking loop (req 6)
Two triggers, same mechanism:
- **Blocked/stuck:** user flags `blocked` with a free-text reason ("don't know which form").
- **Proactive "break this down":** on *any* not-done task that feels too big — no blocked state required
  (Goblin Tools "spiciness" precedent); user may add an optional note.
- Coordinator takes `{ task, acceptance_criteria, reason? }` → emits finer child micro-tasks
  (`parent_task_id` set); the parent becomes `re-tasked` (a container superseded by its children).
- Re-task tree depth is tracked; full history preserved in events.
- Same "doable in one sitting" constraints apply to children.

## 8. Executive-function UX principles (audience-specific)
- **Show the next step, not the mountain.** Collapse completed/future detail by default.
- **Adjustable granularity** (Goblin Tools "spiciness" precedent): "break this down more" anytime.
- **Time-box everything**; lead with the 15-min filter.
- **Low-friction evidence** capture (checkbox default).
- **Celebrate completion**: streaks + visible progress for motivation.

## 9. Explicitly OUT of scope for v1
- Agent executing tasks / tool use (v2).
- Multi-user, shared ideas, multiple approvers (v2).
- Auto-verification of evidence by the agent (v2).
- **External** calendar/email/file integrations (e.g. Google Calendar sync) — the v1 Calendar/Day view is an
  **internal** time-block timeline only; manual evidence only in v1.

## 10. Open questions to resolve next
- **A. Approval bar:** ✅ DECIDED — per-criterion **checkbox default**, optional `url/file/note` evidence.
- **B. Order model:** ✅ DECIDED — linear list with **advisory, non-blocking** `order_index`; any
  not-done task is available (user may do n+1 before n); no hard deps in v1.
- **C. Time tracking:** ✅ DECIDED — **optional focus timer** (start/stop/pause) records focused time
  for accurate calibration + doubles as a focus aid.
- **D. Idea types:** ✅ DECIDED — small fixed list, **auto-suggested** from idea text, user-editable.
- **E. Re-task trigger:** ✅ DECIDED — **both** `blocked/stuck` and a proactive "break this down" on any task.

## 11. UX direction (from reference sketch)
Source: `docs/wireframes/ref-sketch.png` (user-provided). **Mobile-first, two-tab app.**

**Information architecture — two primary tabs (+ Trends secondary):**
- **Idea** — capture + plan. A large free-text box where the user describes the goal, with a **typing /
  "thinking" indicator** → planning is a brief **conversational** exchange: the coordinator may ask 1–2
  clarifying questions (Anthropic "interactive discussion"), then streams the proposed micro-tasks for the
  user to **confirm** before they land in Execute.
- **Execute** — do the work. **Duration chips (15 / 30 / 45)** pinned at the top, then the actionable task
  list. This is the mobile form of the §6 "Do Next" screen. ("Execute" = the human executes — consistent
  with strictly-human-executed v1.)
- **Trends** — secondary view (§6).

**Extracted ideas → implications:**
1. **Mobile-first form factor.** Redraw the screens as phone layouts (current Excalidraw set is desktop).
2. **Conversational idea capture.** The typing indicator implies a streaming/chat feel while the coordinator
   decomposes. Add a `plan_proposed → plan_confirmed / plan_revised` step (events added in §1) and an optional
   clarifying-questions turn before the plan is finalized.
3. **Duration-first Execute view.** 15/30/45 chips are the primary control (matches req 3); they filter the
   list immediately. (Sketch shows 15/30/45; spec also keeps a `60plus` bucket — confirm whether to show it.)
4. **"Calendar UI" → day-timeline (decided).** Tasks render as **time blocks sized by duration** on a day
   timeline (meeting-block style). Internal timeline only; no external calendar sync in v1 (§9). Adds
   `scheduled_start?` to MicroTask. See wireframe `5-calendar-day`.

**New open questions:**
- **F. Idea capture:** ✅ DECIDED — **conversational**: coordinator asks 0–2 clarifying questions, streams
  the proposed plan, user confirms/revises before tasks are created.
- **G. "Calendar UI":** ✅ DECIDED — a **day timeline** where tasks render as **time blocks sized by
  duration** (meeting-block style), internal only (no external calendar sync in v1). Adds `scheduled_start?`.
- **H. Tabs:** ✅ DECIDED — primary IA = **Idea | Execute** (+ Trends secondary), per the sketch; Execute has a
  **List ⇄ Calendar** toggle.
