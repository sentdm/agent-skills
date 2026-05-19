# Sent Agent Skills

**Production-grade agent skills for SMS, WhatsApp, and RCS builders on [Sent](https://sent.dm).**

A Claude Code plugin that packages domain skills for the messy parts of running multi-channel business messaging on Sent — SMS 10DLC/TCR registration, WhatsApp template authoring and classification, RCS RBM agent onboarding, delivery-report analysis, multi-tenant Sender Profile architecture, the tenant template-builder UI, and Meta Embedded Signup.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Skills](https://img.shields.io/badge/skills-7-blue)](#skills)
[![Spec](https://img.shields.io/badge/spec-agentskills.io-purple)](https://agentskills.io/)

---

## What this is

Seven domain skills, matching slash commands, and the references they cite — packaged as an installable Claude Code plugin. Each skill encodes the decisions a senior messaging engineer makes in their head so an agent (Claude, Cursor, Gemini CLI, OpenCode, …) follows the same playbook consistently across all three channels Sent supports.

These skills are **product-domain**, not engineering-lifecycle. They compose cleanly with general engineering skills (e.g. [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)) — install both for full coverage.

---

## Skills

| Skill | Channel | Use it when… | Slash command |
|---|---|---|---|
| [`sender-profile-architect`](./skills/sender-profile-architect/SKILL.md) | all | Designing tenancy around Sender Profiles; webhook routing; rate limits across channels | `/sender-plan` |
| [`messaging-performance-analyzer`](./skills/messaging-performance-analyzer/SKILL.md) | all | Investigating a delivery drop; finding the leak in a sales funnel across SMS/WhatsApp/RCS | `/mdr-analyze` |
| [`sms-10dlc-registration`](./skills/sms-10dlc-registration/SKILL.md) | SMS | Registering a brand + campaign with The Campaign Registry; debugging a TCR rejection | `/sms-register` |
| [`waba-template-author`](./skills/waba-template-author/SKILL.md) | WhatsApp | Drafting a template; classifying utility vs marketing; investigating a rejection | `/waba-template` |
| [`waba-embedded-signup`](./skills/waba-embedded-signup/SKILL.md) | WhatsApp | Integrating Meta Embedded Signup; debugging a stuck signup | `/waba-auth` |
| [`rcs-agent-onboarding`](./skills/rcs-agent-onboarding/SKILL.md) | RCS | Creating + verifying an RBM agent with Google; defining agent capabilities + fallback | `/rcs-onboard` |
| [`template-builder-ui`](./skills/template-builder-ui/SKILL.md) | WhatsApp | Building the tenant-facing template editor; live preview; submission feedback | `/template-ui` |

Plus `/sent` — a meta dispatcher that lists the skills and routes by intent.

---

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

---

## Quick Start

### Claude Code — marketplace install (recommended)

```bash
/plugin marketplace add sentdm/agent-skills
/plugin install sent-skills@sent-skills
```

> If marketplace clone fails due to SSH config, use the explicit HTTPS form:
> ```
> /plugin marketplace add https://github.com/sentdm/agent-skills.git
> /plugin install sent-skills@sent-skills
> ```

### Claude Code — local / development install

```bash
git clone https://github.com/sentdm/agent-skills.git ~/dev/sent-agent-skills
# In Claude Code:
/plugin marketplace add file:///Users/$USER/dev/sent-agent-skills
/plugin install sent-skills@sent-skills
```

### claude.ai (Pro / Max / Team / Enterprise)

```bash
# Zip an individual skill from the repo
cd skills && zip -r waba-template-author.zip waba-template-author/
# Then upload the .zip in claude.ai → Settings → Features → Skills
```

Repeat for each skill you want available.

### Verify the install

In a fresh session:
1. Run `/sent` — the dispatcher should list every skill.
2. Ask *"How do I classify a shipping-update template?"* — the `waba-template-author` skill should auto-activate.
3. Ask *"How do I register a 10DLC campaign?"* — the `sms-10dlc-registration` skill should auto-activate.

---

## How skills work

Skills are loaded by **progressive disclosure** ([spec](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)):

1. **Discovery** — at startup, only the skill `name` + `description` is in context (~100 tokens each).
2. **Activation** — when your request matches a skill's triggers, its `SKILL.md` body loads (under ~5k tokens).
3. **Resources** — referenced files (`references/*.md`) load only when the skill cites them.

This is why each skill's `description` aggressively includes trigger phrases — that's what the agent matches against.

---

## Authoring a new skill

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the quality bar and [`docs/skill-anatomy.md`](./docs/skill-anatomy.md) for the format.

In short:
- One directory per skill under `skills/<kebab-case-name>/`
- One required file: `SKILL.md` with `name` + `description` frontmatter
- Description ≤ 1024 chars and must include both *what* + *when*
- Body ≤ 500 lines; push detail into `references/`
- Run `bash scripts/validate-skills.sh` before opening a PR

---

## Repo layout

```
.claude-plugin/    Plugin + marketplace manifests
.claude/commands/  Slash command shims
skills/            Seven domain skills (one SKILL.md per directory)
  <name>/
    ├── SKILL.md
    ├── references/   ← per-skill reference docs
    └── scripts/      ← per-skill executable utilities (Python, stdlib only)
references/        Cross-cutting only (currently: sent-glossary.md)
docs/              Authoring + setup guides
scripts/           Repo tooling (skill validator)
.github/           Issue + PR templates, validate-skills workflow
```

Each skill directory is self-contained, so it can be zipped and uploaded to claude.ai as a standalone bundle.

---

## Compatibility

Every skill follows the open [Agent Skills format](https://agentskills.io/) and works across any compatible agent — Claude Code, Cursor, Gemini CLI, OpenCode, and others. See [`AGENTS.md`](./AGENTS.md) for cross-tool guidance.

---

## License

MIT — see [`LICENSE`](./LICENSE).

## Contributing

Pull requests welcome. Start with [`CONTRIBUTING.md`](./CONTRIBUTING.md). Bugs and proposals go in [Issues](https://github.com/sentdm/agent-skills/issues).
