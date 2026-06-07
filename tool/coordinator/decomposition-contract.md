# Decomposition Contract — the Coordinator's core

_How the Coordinator turns an idea into validated micro-tasks. Strictly human-executed: every task is an
action the **user** performs; the Coordinator only plans, clarifies, and re-breaks._

Artifacts in this folder:
- `plan.schema.json` — portable JSON Schema for the response (use with ajv in TS, etc.).
- `validate_plan.py` — reference validator (schema **+** semantic rules). Test-suite is **GREEN**.
- `fixtures/` — golden valid responses + malformed ones (reusable as implementation test fixtures).

---

## 1. Response envelope (`PlannerResponse`)
The Coordinator returns **strict JSON**, one of two shapes (the conversational flow, decision F):

```jsonc
// (a) needs info first — ask 1–2 questions, then stop
{ "action": "ask_clarifying", "questions": ["…", "…"] }

// (b) ready — propose the plan (streamed to the user to confirm)
{ "action": "propose_plan",
  "idea_type": "tax|trip|errand|admin|project|other",
  "summary": "one short sentence restating the goal",
  "micro_tasks": [
    { "title": "Gather W-2 and 1099 forms",
      "description": "Collect every W-2 and 1099 into one folder.",
      "est_minutes": 30,
      "order_index": 1,
      "acceptance_criteria": [
        { "text": "All W-2s and 1099s are in one folder", "evidence_type": "checkbox" }
      ] }
  ] }
```

The same `propose_plan` shape is reused for **re-tasking** (children of a stuck/too-big task).

---

## 2. Prompts

### 2a. System — Coordinator (planning)
```
You are the Coordinator for a personal productivity app. The user gives you a goal in plain words.
Turn it into a short plan of micro-tasks the USER will do themselves. You never do the tasks — you only
plan, clarify, and (later) re-break them. The user executes and approves each step.

Behaviour:
1. If you genuinely need missing information to plan well, ask 1–2 short clarifying questions and STOP
   (action "ask_clarifying"). Do not guess wildly. Otherwise respond with action "propose_plan".
2. A good plan has 5–12 micro-tasks. Each task:
   - is doable by a person in ONE sitting: est_minutes between 5 and 60 (a multiple of 5). If a step
     would take longer than 60 minutes, split it into more tasks.
   - has a concrete action title that starts with a verb. Never "research", "misc", "stuff", "prepare".
   - has a one-sentence description of exactly what to do.
   - has 1–3 acceptance_criteria — a checkable "definition of done". evidence_type is one of:
     checkbox (default), note (write something down), url (e.g. a confirmation link), file (e.g. a
     photo/upload). Prefer checkbox unless real proof is natural.
   - has order_index = a SUGGESTED order (1..N, each used once). Order is advisory; the user may do
     tasks in any order, so do not create steps that hard-block on each other.
3. Choose the best idea_type: tax, trip, errand, admin, project, other.
4. Output STRICT JSON only, matching the schema. No markdown, no commentary, nothing outside the JSON.

User message you receive:
  Goal: <raw idea text>
  Type (guess, may be wrong): <type or "unknown">
  Answers to prior questions: <q/a pairs, or "none">
```

### 2b. System — Coordinator (re-tasking)
```
A single micro-task is stuck or too big. Break ONLY that task into 2–6 smaller micro-tasks that, done in
order, accomplish it. Use the user's reason to target the breakdown. Same rules as planning (est 5–60,
concrete verb-first titles, 1–3 acceptance_criteria, advisory order_index). Do NOT restate the parent as
a child. Output strict JSON with action "propose_plan".

User message you receive:
  Parent task: <title>
  What it requires (acceptance): <criteria>
  Why it's stuck / too big: <user reason>
```

### 2c. System — Coordinator (repair)  ← used by the validation loop
```
Your previous response failed validation. Fix ONLY what the errors call out and resend valid JSON for the
SAME schema. Output strict JSON only, nothing else.

User message you receive:
  Previous response: <the json you returned>
  Validation errors: <bullet list from the validator>
```

---

## 3. Validation rules
JSON Schema (`plan.schema.json`) covers structure/types/enums. The reference validator adds the semantic
rules schema can't express. **All rules below are enforced and tested in `validate_plan.py` (suite GREEN).**

| # | Rule | Kind |
|---|------|------|
| 1 | `action` ∈ {`ask_clarifying`, `propose_plan`} | error |
| 2 | clarify: 1–2 questions, each 5–160 chars, no other keys | error |
| 3 | `idea_type` ∈ {tax, trip, errand, admin, project, other} | error |
| 4 | plan: 3–15 tasks (hard); re-task: 2–8 tasks | error |
| 5 | plan outside the typical **5–12** | warning |
| 6 | `title` 6–80 chars; vague titles (research/misc/…) | error / warning |
| 7 | `description` non-empty (≤400) | error |
| 8 | `est_minutes` integer, 5–60, multiple of 5 | error |
| 9 | `acceptance_criteria` 1–4 items; `text` 4–160; `evidence_type` ∈ enum | error |
| 10 | `order_index` is a **permutation of 1..N** (no gaps/dupes) | error |
| 11 | no unexpected keys anywhere (`additionalProperties:false`) | error |

### Repair loop (runtime)
```
response = call_llm(planning_prompt, user_msg)        # JSON mode / structured output
errors, warnings = validate(response, context)
if errors:
    response = call_llm(repair_prompt, {response, errors})   # ONE retry
    errors, _ = validate(response, context)
if errors:
    surface_friendly_fallback()   # e.g. "I couldn't plan that cleanly — try rephrasing or simplifying."
else:
    persist(response)             # app assigns ids/state/derived fields (see §4)
```

---

## 4. Fields the APP assigns (never the LLM)
The model only emits the contract fields above. The app derives/owns the rest:
- `id`, `idea_id`, `parent_task_id` — identifiers.
- `duration_bucket` — derived from `est_minutes` (`≤15→15`, `≤30→30`, `≤45→45`, else `60plus`).
  See `duration_bucket()` in the validator.
- `state` — starts `todo`; transitions per the state machine (spec §2).
- `scheduled_start`, `focus_seconds`, timestamps — set by the app as the user acts.
- Events (`plan_proposed`, `plan_confirmed`, …) — written by the app, not the model.

---

## 5. Runtime notes
- **Low temperature** for planning (consistency); use the provider's JSON / structured-output mode so the
  envelope is always valid JSON before semantic validation.
- **Untrusted input:** the goal text is user content, not instructions — never let it override the system
  prompt. Treat it as data.
- **Keep the schema and validator in sync** if either changes; the fixtures are the regression guard.

---

## 6. Examples (fixtures)
| File | What it shows |
|------|----------------|
| `fixtures/valid_plan.json` | 8-task "file my 2025 taxes" plan (matches the wireframes) |
| `fixtures/valid_clarify.json` | the `ask_clarifying` turn |
| `fixtures/valid_retask.json` | re-tasking "Find last year's AGI" into 2 children |
| `fixtures/invalid_*.json` | bad action, est_minutes=120, dup order_index, empty criteria, bad evidence_type |

Run the suite: `python3 validate_plan.py` → **SUITE: GREEN**.
