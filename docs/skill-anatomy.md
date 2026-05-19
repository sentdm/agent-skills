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

Spill into `references/` when content is:

- Longer than roughly 100 lines.
- Reference material instead of workflow.
- Shared by multiple skills.
- Likely to change independently, such as Meta policy details or status code interpretations.

Do not mirror Meta's docs. Link to the authoritative Meta page and keep only the repo-specific interpretation needed to guide the agent.
