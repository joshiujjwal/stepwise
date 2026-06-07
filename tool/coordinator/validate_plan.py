#!/usr/bin/env python3
"""Reference validator for Coordinator PlannerResponse objects.

Pure-Python, no dependencies. Enforces the structural contract in
`plan.schema.json` PLUS semantic rules JSON Schema can't express
(order_index permutation, duration buckets, vague-title heuristics,
context-aware task counts).

Usage:
  python3 validate_plan.py                 # run the fixture test-suite (red/green)
  python3 validate_plan.py FILE.json       # validate one response (context: plan)
  python3 validate_plan.py --retask F.json # validate a re-tasking response
"""
from __future__ import annotations

import json
import os
import sys

EVIDENCE = {"checkbox", "note", "url", "file"}
IDEA_TYPES = {"tax", "trip", "errand", "admin", "project", "other"}
VAGUE = {"research", "stuff", "misc", "miscellaneous", "things", "etc",
         "other", "task", "todo", "various", "prepare", "organize"}

PLAN_SOFT_MIN, PLAN_SOFT_MAX = 5, 12       # typical plan size -> warn outside
PLAN_HARD_MIN, PLAN_HARD_MAX = 3, 15       # hard fail outside
RETASK_MIN, RETASK_MAX = 2, 8


def _err(errors, path, msg):
    errors.append(f"{path}: {msg}")


def validate(obj, context="plan"):
    """Return (errors, warnings). A response is valid iff errors == []."""
    errors, warnings = [], []
    if not isinstance(obj, dict):
        return ["$: response must be a JSON object"], []
    action = obj.get("action")
    if action == "ask_clarifying":
        _validate_clarify(obj, errors)
    elif action == "propose_plan":
        _validate_plan(obj, context, errors, warnings)
    else:
        _err(errors, "$.action", f"must be 'ask_clarifying' or 'propose_plan', got {action!r}")
    return errors, warnings


def _validate_clarify(obj, errors):
    extra = set(obj) - {"action", "questions"}
    if extra:
        _err(errors, "$", f"unexpected keys for ask_clarifying: {sorted(extra)}")
    qs = obj.get("questions")
    if not isinstance(qs, list) or not (1 <= len(qs) <= 2):
        _err(errors, "$.questions", "must be a list of 1-2 questions")
        return
    for i, q in enumerate(qs):
        if not isinstance(q, str) or not (5 <= len(q.strip()) <= 160):
            _err(errors, f"$.questions[{i}]", "must be a 5-160 char string")


def _validate_plan(obj, context, errors, warnings):
    extra = set(obj) - {"action", "idea_type", "summary", "micro_tasks"}
    if extra:
        _err(errors, "$", f"unexpected keys for propose_plan: {sorted(extra)}")
    if obj.get("idea_type") not in IDEA_TYPES:
        _err(errors, "$.idea_type", f"must be one of {sorted(IDEA_TYPES)}")
    summary = obj.get("summary")
    if summary is not None and (not isinstance(summary, str) or len(summary) > 200):
        _err(errors, "$.summary", "must be a string <= 200 chars")

    tasks = obj.get("micro_tasks")
    if not isinstance(tasks, list):
        _err(errors, "$.micro_tasks", "must be a list")
        return
    n = len(tasks)
    lo, hi = (RETASK_MIN, RETASK_MAX) if context == "retask" else (PLAN_HARD_MIN, PLAN_HARD_MAX)
    if not (lo <= n <= hi):
        _err(errors, "$.micro_tasks", f"{context}: expected {lo}-{hi} tasks, got {n}")
    if context == "plan" and n and not (PLAN_SOFT_MIN <= n <= PLAN_SOFT_MAX):
        warnings.append(f"$.micro_tasks: {n} tasks is outside the typical {PLAN_SOFT_MIN}-{PLAN_SOFT_MAX}")

    orders = []
    for i, t in enumerate(tasks):
        p = f"$.micro_tasks[{i}]"
        if not isinstance(t, dict):
            _err(errors, p, "must be an object")
            continue
        extra = set(t) - {"title", "description", "est_minutes", "acceptance_criteria", "order_index"}
        if extra:
            _err(errors, p, f"unexpected keys: {sorted(extra)}")

        title = t.get("title")
        if not isinstance(title, str) or not (6 <= len(title.strip()) <= 80):
            _err(errors, f"{p}.title", "must be a 6-80 char string")
        elif title.strip().lower() in VAGUE or title.strip().split()[0].lower() in VAGUE and len(title.split()) == 1:
            warnings.append(f"{p}.title: vague title {title!r} - make it a concrete action")

        desc = t.get("description")
        if not isinstance(desc, str) or not desc.strip():
            _err(errors, f"{p}.description", "must be a non-empty string")

        em = t.get("est_minutes")
        if isinstance(em, bool) or not isinstance(em, int) or not (5 <= em <= 60) or em % 5 != 0:
            _err(errors, f"{p}.est_minutes", "must be an integer 5-60, multiple of 5")

        oi = t.get("order_index")
        if isinstance(oi, bool) or not isinstance(oi, int) or oi < 1:
            _err(errors, f"{p}.order_index", "must be an integer >= 1")
        else:
            orders.append(oi)

        _validate_criteria(t.get("acceptance_criteria"), p, errors)

    if orders and sorted(orders) != list(range(1, len(tasks) + 1)):
        _err(errors, "$.micro_tasks[].order_index",
             f"must be a permutation of 1..{len(tasks)} (got {sorted(orders)})")


def _validate_criteria(acs, p, errors):
    if not isinstance(acs, list) or not (1 <= len(acs) <= 4):
        _err(errors, f"{p}.acceptance_criteria", "must be a list of 1-4 criteria")
        return
    for j, ac in enumerate(acs):
        cp = f"{p}.acceptance_criteria[{j}]"
        if not isinstance(ac, dict):
            _err(errors, cp, "must be an object")
            continue
        extra = set(ac) - {"text", "evidence_type"}
        if extra:
            _err(errors, cp, f"unexpected keys: {sorted(extra)}")
        text = ac.get("text")
        if not isinstance(text, str) or not (4 <= len(text.strip()) <= 160):
            _err(errors, f"{cp}.text", "must be a 4-160 char string")
        if ac.get("evidence_type") not in EVIDENCE:
            _err(errors, f"{cp}.evidence_type", f"must be one of {sorted(EVIDENCE)}")


def duration_bucket(est_minutes):
    """App-side derived field (NOT produced by the LLM)."""
    if est_minutes <= 15:
        return "15"
    if est_minutes <= 30:
        return "30"
    if est_minutes <= 45:
        return "45"
    return "60plus"


# ---- fixture test-suite ----------------------------------------------------
EXPECT = {
    "valid_plan.json": ("plan", True),
    "valid_clarify.json": ("plan", True),
    "valid_retask.json": ("retask", True),
    "invalid_action.json": ("plan", False),
    "invalid_est_minutes.json": ("plan", False),
    "invalid_order_index.json": ("plan", False),
    "invalid_empty_criteria.json": ("plan", False),
    "invalid_evidence_type.json": ("plan", False),
    "invalid_extra_keys.json": ("plan", False),
}


def _run_suite():
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
    ok = True
    for name, (ctx, should_pass) in sorted(EXPECT.items()):
        with open(os.path.join(here, name)) as f:
            obj = json.load(f)
        errors, warnings = validate(obj, ctx)
        passed = not errors
        good = passed == should_pass
        ok = ok and good
        mark = "PASS" if good else "XXXX"
        exp = "valid" if should_pass else "invalid"
        print(f"[{mark}] {name:26} expect={exp:7} errors={len(errors)} warnings={len(warnings)}")
        if not good:
            for e in errors:
                print("        -", e)
    print("\nSUITE:", "GREEN" if ok else "RED")
    return ok


def _validate_file(path, context):
    with open(path) as f:
        obj = json.load(f)
    errors, warnings = validate(obj, context)
    for w in warnings:
        print("warn:", w)
    for e in errors:
        print("error:", e)
    print("VALID" if not errors else "INVALID")
    return 0 if not errors else 1


def main(argv):
    if len(argv) >= 3 and argv[1] == "--retask":
        return _validate_file(argv[2], "retask")
    if len(argv) >= 2:
        return _validate_file(argv[1], "plan")
    return 0 if _run_suite() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
