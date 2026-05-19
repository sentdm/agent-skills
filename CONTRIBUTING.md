# Contributing to Sent Agent Skills

Thanks for your interest in contributing. This repo is a collection of messaging-platform skills (SMS, WhatsApp, RCS) for AI coding agents, published as an MIT-licensed Claude Code plugin and conformant to the open [Agent Skills format](https://agentskills.io/).

By contributing, you agree that your contributions will be licensed under the MIT License.

## Quality Bar

Every skill must be:

- **Specific** — actionable steps, not vague advice. "Run `bash scripts/validate-skills.sh`" beats "verify the skill is valid."
- **Verifiable** — clear exit criteria. Every checkbox in the `## Verification` section should have evidence (script output, webhook payload, screenshot).
- **Battle-tested** — based on actual carrier / Meta / Google RBM engineering, not theoretical ideals or restatements of the platforms' docs.
- **Minimal** — only the content needed to guide the agent correctly. If removing a section wouldn't change behavior, remove it.

## Adding a New Skill

1. Create a directory under `skills/` with a kebab-case name (`[a-z0-9-]+`, ≤ 64 chars).
2. Add a `SKILL.md` following [`docs/skill-anatomy.md`](./docs/skill-anatomy.md).
3. Include YAML frontmatter with `name` and `description`.
4. `name` must match the directory name and must not be `anthropic` or `claude`.
5. `description` must:
   - Be ≤ 1024 characters
   - Start with what the skill does in third person ("Analyzes…", "Designs…", "Implements…")
   - Include at least one explicit "Use when …" trigger condition
   - Include the trigger phrases users actually say ("10DLC", "TCR", "RBM agent", "MDR", "embedded signup", "template category")
6. Body stays ≤ 500 lines. Push detail to `references/<name>.md` when it grows beyond that.
7. Run `bash scripts/validate-skills.sh` and confirm it exits 0.

## Standard Skill Anatomy

The repo follows the addyosmani / Anthropic convention:

```markdown
---
name: skill-name
description: …
---

# Skill Title

## Overview
What this skill does and why it matters.

## When to Use
Bullet list of triggers and exclusions.

## [Process / Workflow / Core Process]
Step-by-step instructions.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| Excuse to skip a step | Why the excuse is wrong |

## Red Flags
Observable signs the skill is being applied incorrectly.

## Verification
- [ ] Exit criteria with evidence
```

Equivalent headings (`Workflow`, `How It Works`, `Core Process`) are fine when they fit the skill better.

## Modifying Existing Skills

- Keep changes focused and minimal.
- Preserve the existing structure and tone unless there's a reason to change it.
- Re-run the validator after every edit.

## Things Not to Do

- Don't duplicate content between skills — reference the other skill by name (`See sent-skills:waba-template-author`) instead.
- Don't copy carrier (Meta, TCR, Google RBM) docs verbatim — link to them. Those docs update frequently; mirroring rots quickly.
- Don't create supporting files unless content exceeds ~100 lines or you ship runnable scripts.
- Don't create an empty `scripts/` directory just to match another skill — only add `scripts/` when the skill actually ships executables.
- Don't put reference material inside skill directories — `references/` is at the repo root.
- Don't add skills that restate engineering best practices that aren't channel/Sent-specific. Generic engineering skills belong in repos like [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills); this repo is product-domain only.

## Reporting Issues

Open an issue if:
- A skill gives incorrect or outdated guidance (a carrier API changed, Meta policy changed, TCR vetting changed, Google RBM verification process changed)
- A channel-specific workflow is missing coverage
- Cross-skill references are inconsistent

Issue templates live in `.github/ISSUE_TEMPLATE/`.

## Pull Requests

- One skill per PR when adding new skills.
- Include in the description: what triggered the contribution, how you tested it, and a sample interaction transcript if relevant.
- CI runs `scripts/validate-skills.sh` automatically on every PR that touches `skills/**`.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md). Reports of unacceptable behavior go to the maintainers via GitHub Issues marked `conduct` or to the contact listed in [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
