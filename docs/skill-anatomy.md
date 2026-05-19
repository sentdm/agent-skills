# Skill Anatomy

This is the contract between contributors and `scripts/validate-skills.sh`. Follow it for every new or changed skill.

## File Location

Each skill lives in its own directory:

```text
skills/<kebab-case-name>/SKILL.md
```

The directory name is the skill name. Use lowercase letters, digits, and hyphens only, with a maximum length of 64 characters.

## Frontmatter Rules

Every `SKILL.md` starts with YAML frontmatter:

```markdown
---
name: skill-name
description: Analyzes... Use when...
---
```

The validator requires:

- `name` is present.
- `name` matches the containing directory.
- `name` matches `^[a-z0-9-]{1,64}$`.
- `name` is not `anthropic` or `claude`.
- `description` is present and no more than 1024 characters.
- `description` includes at least one explicit `Use when` trigger phrase.

Write the description for discovery. It should say what the skill does, when to use it, and the trigger phrases users actually type.

## Recommended Section Anatomy

Use this shape unless the skill has a better domain-specific equivalent:

```markdown
# Skill Title

## Overview
What this skill does and what outcome it should produce.

## When to Use
Trigger conditions, exclusions, and handoffs to other skills.

## Process
The workflow the agent should follow.

## Common Rationalizations
Tempting shortcuts and why they are wrong.

## Red Flags
Observable signs the skill is being misapplied.

## Verification
- [ ] Evidence-backed exit criteria.
```

Equivalent headings are allowed. For example, `Workflow`, `Core Process`, or `How It Works` can replace `Process` when they fit the skill better.

## Writing Principles

- Prefer process over knowledge. A skill should change how the agent works, not just provide background reading.
- Prefer specific over general. Use concrete checks, examples, and failure modes.
- Include anti-rationalization guidance when agents are likely to skip a necessary step.
- Keep the body under 500 lines. If it approaches that limit, move supporting material to `references/`.
- Make verification observable. "Check delivery-rate math against raw counts" is stronger than "ensure the analysis is correct."

## Cross-Skill References

Reference other skills by name, not by file path:

```text
See sent-skills:waba-template-author.
```

Use cross-skill references when the user intent should hand off to another skill or when a workflow naturally composes with another skill. Do not duplicate another skill's instructions.

## When to Use References

Spill into the skill's `references/` when content is:

- Longer than roughly 100 lines.
- Reference material instead of workflow.
- Likely to change independently, such as Meta policy details or status code interpretations.

Single-skill references live at `skills/<name>/references/`. Cross-cutting references shared by every skill live at top-level `references/` (currently only `sent-glossary.md`).

Do not mirror Meta's docs. Link to the authoritative Meta page and keep only the repo-specific interpretation needed to guide the agent.

## Per-skill bundling

Each skill is a self-contained directory. Reference docs and executable scripts live **inside** the skill directory so the skill is portable as a standalone zip (e.g. for upload to claude.ai):

```text
skills/<name>/
  ├── SKILL.md
  ├── references/   ← per-skill reference docs (cited by this SKILL.md)
  └── scripts/      ← per-skill executables (Python 3.11+, stdlib only)
```

Reference citations in a SKILL.md resolve **relative to the SKILL.md file**, not the repo root. Write `references/foo.md`, not `../../references/foo.md`.

Only one reference is cross-cutting and lives at the top-level `references/`: `sent-glossary.md`. Everything else belongs inside the citing skill's directory.

## Eval cases

Each skill ships `evals/<skill>.yaml` with 3–5 trigger cases exercising both positive and negative discovery. The format is:

```yaml
skill: <name>
cases:
  - query: "How do I classify a shipping update template?"
    expect: trigger
    rationale: "Direct template-classification question — should activate."
  - query: "Write me a unit test for a React component."
    expect: no_trigger
    rationale: "Generic engineering — out of scope."
  - query: "What's the difference between utility and marketing?"
    expect: ambiguous
    rationale: "Could be WhatsApp template category, could be a general marketing question."
```

`expect` is one of `trigger`, `no_trigger`, or `ambiguous`. Run the suite via `bash scripts/run-evals.sh`.
