# AGENTS.md

Cross-tool guidance for AI agents working with this repository — Claude Code, Cursor, Gemini CLI, OpenCode, Copilot, Codex, and any other agent that supports the open [Agent Skills format](https://agentskills.io/).

## What's in here

A messaging-platform skill collection for builders on [Sent](https://sent.dm) — covering **SMS, WhatsApp, and RCS**. Seven skills under `skills/`, matching slash commands under `.claude/commands/`, and reference docs under `references/`. Built and tested as a Claude Code plugin, but the skills themselves are tool-agnostic.

## Intent → Skill Mapping

If the user's request matches one of these intents, invoke the corresponding skill:

| Intent | Channel | Skill |
|---|---|---|
| Register a brand + campaign with TCR / 10DLC | SMS | `sent-skills:sms-10dlc-registration` |
| Debug a TCR rejection, vetting score, or throughput issue | SMS | `sent-skills:sms-10dlc-registration` |
| Author or classify a WhatsApp message template | WhatsApp | `sent-skills:waba-template-author` |
| Why was a template rejected or re-categorized? | WhatsApp | `sent-skills:waba-template-author` |
| Implement or debug Meta Embedded Signup | WhatsApp | `sent-skills:waba-embedded-signup` |
| OAuth, Facebook Login for Business, `config_id` | WhatsApp | `sent-skills:waba-embedded-signup` |
| Build the tenant-facing template submission UI | WhatsApp | `sent-skills:template-builder-ui` |
| Create + verify an RCS Business Messaging (RBM) agent | RCS | `sent-skills:rcs-agent-onboarding` |
| Agent capabilities, suggested actions, SMS fallback | RCS | `sent-skills:rcs-agent-onboarding` |
| Investigate delivery-rate issues across any channel | all | `sent-skills:messaging-performance-analyzer` |
| Find the leak in a sales / notification funnel | all | `sent-skills:messaging-performance-analyzer` |
| Design multi-tenant architecture for a messaging app | all | `sent-skills:sender-profile-architect` |
| Webhook routing across tenants and channels | all | `sent-skills:sender-profile-architect` |

If the request spans multiple intents, name the primary skill and reference the others.

## Tool-Specific Notes

### Claude Code

Skills auto-activate by `description` match. Slash commands live in `.claude/commands/` and are thin shims that invoke the skill. The plugin is installable via:

```
/plugin marketplace add sentdm/agent-skills
/plugin install sent-skills@sent-skills
```

### OpenCode

OpenCode uses a skill-driven execution model: invoke the skill via the `skill` tool whenever an intent matches, and follow the instructions exactly. Do not partially apply a skill.

### Cursor

Reference a skill by reading its `SKILL.md` file via the codebase context. Cursor doesn't enforce activation, so a CONTRIBUTING-style human cue ("use the waba-template-author skill for this") is helpful when committing prompts to a project's `.cursor/rules`.

### Gemini CLI

Skills are loaded via `gemini extensions` (or equivalent in the current version). Each skill's `description` is the discovery signal. See the [Gemini CLI skills docs](https://geminicli.com/docs/cli/skills/) for the latest install path.

### Other agents

The format is standardized. Any agent that supports `SKILL.md`-based skills should work. See the [agentskills.io client showcase](https://agentskills.io/) for the current list.

## Working In This Repo

When asked to add or modify a skill:

1. Read [`docs/skill-anatomy.md`](./docs/skill-anatomy.md) for the format contract.
2. Place the file at `skills/<kebab-case-name>/SKILL.md`.
3. Run `bash scripts/validate-skills.sh` and confirm it exits 0 before opening a PR.
4. Reference other skills by name (`sent-skills:<skill-name>`), not by file path.
5. Don't mirror Meta / TCR / Google RBM docs — link them. Don't restate generic engineering advice — that belongs elsewhere.

## Composing With Other Skill Collections

This repo is **messaging-platform domain only** — SMS, WhatsApp, RCS on Sent. For general engineering-lifecycle skills (spec → plan → build → test → ship), pair it with a lifecycle plugin like [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills). Slash commands intentionally use domain verbs (`/waba-template`, `/sms-register`, `/rcs-onboard`, `/mdr-analyze`) to avoid collisions with lifecycle commands (`/spec`, `/build`, `/ship`).
