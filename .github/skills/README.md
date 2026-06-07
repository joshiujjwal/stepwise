# .github/skills

Reusable, domain-specific agent skills for stepwise (VS Code `SKILL.md`-style docs or prompt files).

Start from the planner domain knowledge that already exists:
- **`tool/coordinator/decomposition-contract.md`** — the prompts, JSON schema, and validation rules for
  turning an idea into micro-tasks. Any agent touching `lib/coordinator/` should read it first.

Suggested skills to add as the app grows:
- **change-a-coordinator-prompt** — keep `lib/coordinator/prompts.dart`, `tool/coordinator/plan.schema.json`,
  and `validate_plan.py` in sync; re-run the validator suite.
- **add-a-screen** — wire a `lib/ui/` screen to its wireframe in `docs/wireframes/` and the spec section.
