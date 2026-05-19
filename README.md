# Sent Agent Skills

**Production-grade agent skills for WhatsApp Business API builders.**

A Claude Code plugin that packages domain skills for the messy parts of building on the WhatsApp Business Platform — template authoring and classification, delivery-report analysis, multi-tenant Sender Profile architecture, the tenant template-builder UI, and Meta Embedded Signup.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Skills](https://img.shields.io/badge/skills-5-blue)](#skills)
[![Spec](https://img.shields.io/badge/spec-agentskills.io-purple)](https://agentskills.io/)

---

## What this is

Five domain skills, six slash commands, and the references they cite — packaged as an installable Claude Code plugin. Each skill encodes the decisions a senior WABA engineer makes in their head so an agent (Claude, Cursor, Gemini CLI, OpenCode, …) follows the same playbook consistently.

These skills are **product-domain**, not engineering-lifecycle. They compose cleanly with general engineering skills (e.g. [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)) — install both for full coverage.

---

## Skills

| Skill | Use it when… | Slash command |
|---|---|---|
| [`waba-template-author`](./skills/waba-template-author/SKILL.md) | Drafting a template; classifying utility vs marketing; investigating a rejection | `/waba-template` |
| [`messaging-performance-analyzer`](./skills/messaging-performance-analyzer/SKILL.md) | Investigating an MDR drop; finding the leak in a sales funnel | `/mdr-analyze` |
| [`sender-profile-architect`](./skills/sender-profile-architect/SKILL.md) | Designing tenancy around Sender Profiles; webhook routing; rate limits | `/sps-plan` |
| [`template-builder-ui`](./skills/template-builder-ui/SKILL.md) | Building the tenant-facing template editor; live preview; submission feedback | `/template-ui` |
| [`waba-embedded-signup`](./skills/waba-embedded-signup/SKILL.md) | Integrating Meta Embedded Signup; debugging a stuck signup | `/waba-auth` |

Plus `/sent` — a meta dispatcher that lists the skills and routes by intent.

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
1. Run `/sent` — the dispatcher should list the five skills.
2. Ask *"How do I classify a shipping-update template?"* — the `waba-template-author` skill should auto-activate.

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
skills/            Five domain skills (one SKILL.md per directory)
references/        Supplementary docs cited by the skills
docs/              Authoring + setup guides
scripts/           Repo tooling (skill validator)
.github/           Issue + PR templates, validate-skills workflow
```

---

## Compatibility

Every skill follows the open [Agent Skills format](https://agentskills.io/) and works across any compatible agent — Claude Code, Cursor, Gemini CLI, OpenCode, and others. See [`AGENTS.md`](./AGENTS.md) for cross-tool guidance.

---

## License

MIT — see [`LICENSE`](./LICENSE).

## Contributing

Pull requests welcome. Start with [`CONTRIBUTING.md`](./CONTRIBUTING.md). Bugs and proposals go in [Issues](https://github.com/sentdm/agent-skills/issues).
