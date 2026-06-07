# Research Brief — Agentic Micro-Task Coordinator

_Pre-build research. Not committed to the repo. Date: 2026-06-06._

## The idea (restated)
A system where a user enters an idea/task; a per-idea **agent coordinator** decomposes it into
**time-bound, doable micro-tasks**; state advances **only on human approval** once **acceptance
criteria** are met (e.g. "documents gathered", "form submitted"); users can browse/filter micro-tasks
by **duration (15/30/45 min)**, see **per-task state/progress** (which step, how many left), view
**trends/analytics**, and **re-task** unfinished micro-tasks into finer steps.

This is a **human-in-the-loop (HITL) agentic GTD** — the agent *plans & re-plans*, the human *executes & approves*.

---

## Thread 1 — Product landscape (closest analogs + the gap)

| Product | What it does | Overlap | Missing vs your idea |
|---|---|---|---|
| **Goblin Tools "Magic ToDo"** (goblin.tools) | Breaks any task into steps; "spiciness" slider controls granularity; break any step down further; "Estimator" guesses time. Neurodivergent-focused. | Decomposition (req 2), recursive re-tasking (req 6), time estimate (req 3) | No state machine, no approval gates, no acceptance criteria, no trends, no per-idea coordinator |
| **Motion / Reclaim.ai** | AI auto-schedules tasks into time blocks | Time-boxing (req 3) | No decomposition, no agent coordinator, no approval/acceptance gates |
| **Taskade AI / Notion AI / Saga** | Generate task lists/projects from a prompt | Idea→tasks (req 1,2) | One-shot generation; no stateful coordinator, no HITL gates, no re-tasking loop |
| **Autonomous frameworks** (BabyAGI, AutoGPT, AgentGPT, Lindy, Cognosys) | Goal → task list → agent executes autonomously | Decomposition + execution (req 2) | Fully autonomous (no human-approval state gates); built to remove the human, not coordinate one |
| **Hermes Kanban** (seen in discourse) | Drop a rough idea on a board, agent builds it | Idea→board (req 1,2) | Aims for "zero human rework"; opposite of your approval-gated philosophy |
| **Statewright** (Show HN) | Visual state machines to make agents reliable | State machine for reliability | A dev tool, not an end-user task coordinator |

**The gap (your wedge):** No mainstream tool combines (a) a *persistent per-idea coordinator*, (b)
*time-boxed micro-tasks for a human*, (c) an *approval-gated state machine with acceptance/evidence*,
(d) *duration filtering*, (e) *trends*, and (f) *adaptive re-tasking*. Goblin Tools is the nearest
single-feature precedent (decompose + estimate + recursive); everything else is either autonomous
(removes the human) or pure scheduling (no decomposition).

---

## Thread 2 — Technical architecture patterns (mapped to your 6 requirements)

Sourced from Anthropic "Building Effective Agents" and LangChain "Plan-and-Execute Agents".

| Your requirement | Proven pattern | Notes |
|---|---|---|
| **1. Enter idea** | **Routing** (classify intent → template) | Optionally classify idea type (tax, trip, errand) to seed a better plan |
| **2. Coordinator → time-bound micro-tasks; advance on human approval + acceptance** | **Orchestrator-workers** (coordinator dynamically decomposes) + **Plan-and-Execute** (planner emits multi-step plan) + **HITL checkpoints** (pause for human approval/judgement) + **Evaluator-optimizer** (check acceptance criteria) | This is the core. Agent decomposes; each micro-task is a node with a "definition of done"; the human approves to transition state. Anthropic: agents "pause for human feedback at checkpoints" with "stopping conditions". |
| **3. Filter micro-tasks by duration (15/30/45)** | LLM estimates `est_minutes` at plan time; bucket + filter | Goblin Tools "Estimator" is the precedent. Estimates are guesses — allow human override. |
| **4. Per-task state / nth step / how many left** | **State machine** per micro-task + ordered DAG; track current index & % complete | `todo → in_progress → awaiting_approval → done`, plus `blocked` |
| **5. Views & trends** | **Event-sourced** state log → analytics | Completion rate, time-to-done, throughput by duration bucket, streaks. Event log makes trends trivial. |
| **6. Re-task unfinished into finer steps** | **Re-planning loop** (plan-and-execute re-planner) + recursive decomposition | On `blocked`, coordinator decomposes the failed micro-task into finer sub-steps. Goblin Tools' "break it down further" is the UX precedent. |

**Anthropic's 3 principles to honor:** (1) keep the design **simple**; (2) **transparency** — show the
agent's planning steps to the user; (3) a well-documented **tool/interface** for the agent.

**Build guidance:** start as a **workflow** (predictable code paths + small fixed state machine), not a
fully autonomous loop. Add autonomy only where it demonstrably helps.

---

## Thread 3 — Current discourse (what people are actually saying)

Thin window (X unavailable, Reddit partly rate-limited) but the signal strongly **corroborates the HITL thesis**:

- **Autonomous agents fail on trust/maintenance.** r/AI_Agents "Stop building AI agents" (329 comments):
  _"The maintenance burden is what actually kills these projects. The Loom video shows the happy path,
  but nobody shows the 3am Slack message when the agent starts approving the wrong invoices or
  double-booking."_ → **Your approval gates are the antidote to this exact failure.**
  https://www.reddit.com/r/AI_Agents/comments/1taei9m/stop_building_ai_agents/
- **State machines are the reliability trend.** "Show HN: Statewright — Visual state machines that make
  AI agents reliable" (126 pts). → Validates a state-machine core.
- **"Agent" is an overloaded label.** _"a word that means six different things depending on who's selling."_
  → **Positioning:** market this as a *human-in-the-loop task coordinator*, not "an AI agent".
- **People want persistence, not one-off chat.** "How an AI OS turns tasks into agents": _"Most people
  still use AI like a single helper, so every task starts and ends inside one chat box."_ → Validates the
  *persistent per-idea coordinator*.
- **"Zero human rework" is unrealistic.** A Hermes Kanban test video literally titled _"It Made a Video,
  But Missed the Point."_ → Reinforces human checkpoints over full autonomy.

---

## Design implications / recommended architecture (v1)

1. **Strictly human-executed (v1 — DECIDED).** Agent **plans/re-plans only**; human **executes &
   approves** every micro-task. No agent tool-execution/sandboxing in v1. This is the reliability sweet
   spot the discourse is begging for. (Hybrid agent-execution is a v2 option.)
2. **Event-sourced state machine per idea.** Micro-task lifecycle:
   `todo → in_progress → awaiting_approval → done`, plus `blocked → (re-task)`. Human approval is the
   transition into `done`; acceptance criteria are the **guards**.
3. **Acceptance criteria = checkable "definition of done"** per micro-task (text + optional evidence:
   uploaded doc, URL of submitted form, checkbox). **Human attests** in v1; agent auto-verify (evaluator)
   is a v2 option.
4. **Duration estimate at plan time**, bucketed (15/30/45/60+), human-overridable.
5. **Re-planner on `blocked`** decomposes the stuck micro-task into finer steps (recursive).
6. **Keep v1 a workflow** with a small fixed state machine; add agent autonomy only where it helps.

### Minimal component sketch
- **Coordinator (LLM planner)** per idea → micro-task DAG `{title, est_minutes, acceptance_criteria, deps}`
- **State store + event log** (powers progress view + trends)
- **HITL approval queue** with acceptance gate
- **Re-planner** (blocked → finer steps)
- **UI**: task board · duration filter · progress view · trends dashboard

---

## Decisions locked
1. **Execution model:** ✅ **Strictly human-executed in v1** — agent only plans/decomposes/re-plans.
2. **Audience:** ✅ **Single-user personal productivity / executive-function aid** (ADHD-friendly, à la Goblin Tools).

## Open questions before we scaffold
3. **Tech stack** (deferred): full-stack TS (Next.js + Prisma + SQLite) vs Python (FastAPI + SQLite) vs other.
4. **LLM provider** preference (OpenAI / Anthropic / local).
5. **Project name** (kebab-case) + GitHub visibility (public/private).

## Sources
- Anthropic — Building Effective Agents: https://www.anthropic.com/engineering/building-effective-agents
- LangChain — Plan-and-Execute Agents: https://blog.langchain.dev/planning-agents/
- Goblin Tools (About): https://goblin.tools/About
- r/AI_Agents — "Stop building AI agents": https://www.reddit.com/r/AI_Agents/comments/1taei9m/stop_building_ai_agents/
- Show HN — Statewright: https://github.com/statewright/statewright
- Raw discourse dump: captured during research via the last30days engine (not committed).
