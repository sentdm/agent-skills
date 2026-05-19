# CLAUDE.md

Repo-level instructions for Claude Code working inside this repository.

## Project

This is the **sent-skills** plugin: a Claude Code plugin distribution of agent skills for [Sent](https://sent.dm) — the unified messaging platform for **SMS, WhatsApp, and RCS**. Skills are MIT-licensed, conformant to the [open Agent Skills format](https://agentskills.io/), and live under `skills/`.

## Layout

```
skills/           → SKILL.md files (one per domain skill, spanning SMS/WhatsApp/RCS)
  <name>/
    ├── SKILL.md
    ├── references/   ← per-skill reference docs (resolved relative to SKILL.md)
    └── scripts/      ← per-skill Python utilities (stdlib only)
references/       → Cross-cutting docs only (currently: sent-glossary.md)
.claude/commands/ → Slash commands (thin shims that invoke skills)
.claude-plugin/   → plugin.json + marketplace.json
docs/             → Authoring + setup guides
scripts/          → Repo tooling (validator)
.github/          → Issue + PR templates, CI
```

## Command ↔ skill mapping

| Slash command | Skill |
|---|---|
| `/mdr-analyze` | `messaging-performance-analyzer` |
| `/rcs-onboard` | `rcs-agent-onboarding` |
| `/sender-plan` | `sender-profile-architect` |
| `/sms-register` | `sms-10dlc-registration` |
| `/template-ui` | `template-builder-ui` |
| `/waba-auth` | `waba-embedded-signup` |
| `/waba-template` | `waba-template-author` |
| `/sent` | `sent` (meta-dispatcher) |

## Authoring Rules (apply when adding or editing skills)

- Every skill must live at `skills/<name>/SKILL.md` and be validated by `bash scripts/validate-skills.sh`. Run it before every PR.
- `description` must include both *what* and *when* — at least one "Use when …" clause. Trigger phrases users actually say belong in the description, not the body.
- `name` is lowercase + hyphens + digits only, ≤ 64 chars, must equal the directory name, and must not be `anthropic` or `claude`.
- Keep `SKILL.md` ≤ 500 lines. Move details to `references/<topic>.md`.
- Cross-skill references use the **skill name** (`sent-skills:waba-template-author`), not file paths.
- Don't duplicate Meta / TCR / Google RBM docs — link them. Don't restate generic engineering best practices — those belong in lifecycle skill repos.

Reference paths in a SKILL.md are resolved **relative to the SKILL.md file**, not the repo root. `references/foo.md` in skill X means `skills/X/references/foo.md`.

Per-skill scripts live under `skills/<name>/scripts/` and are Python 3.11+, stdlib-only. Invoke via `python skills/<name>/scripts/<script>.py` from the repo root. Each script must ship paired `good.json`/`bad.json` fixtures.

## Validator

```bash
bash scripts/validate-skills.sh
```

Exits 0 on success. Checks frontmatter presence, name regex + directory match, description length and "Use when" trigger, and body line count. The same script runs in CI via `.github/workflows/validate-skills.yml`.

## Commands

- `npm test` — not applicable (this is a documentation project)
- Validate: `bash scripts/validate-skills.sh`

## Boundaries

- **Always:** keep skills product-domain — the messy bits of operating SMS (10DLC/TCR), WhatsApp (WABA, Meta policy), and RCS (RBM, Google verification) on Sent. Use `references/` for supplementary detail.
- **Always:** match the addyosmani / Anthropic recommended anatomy (Overview, When to Use, Workflow, Common Rationalizations, Red Flags, Verification) — equivalent headings are fine.
- **Never:** add a skill that's generic engineering advice (those belong in lifecycle repos like [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)).
- **Never:** mirror carrier or Meta API docs inside SKILL.md — link to them so the skill stays small and current.
- **Never:** commit secrets, tokens, `config_id`, TCR campaign IDs, or RBM agent IDs to references — those are illustrative only.

## When working in this repo

For non-trivial changes, use the addyosmani lifecycle skills if installed (`/spec`, `/plan`, `/build`). For this repo specifically, the work usually is:
- Drafting or revising a SKILL.md → re-run the validator
- Adding a reference doc → update the citing SKILL.md to link it
- Adding a slash command → keep it a thin shim that invokes one skill
