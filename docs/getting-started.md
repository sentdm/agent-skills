# Getting Started

This guide walks through installing `sent-skills`, checking that Claude Code can see it, and running one template-authoring task end to end.

## Prerequisites

- Claude Code installed and signed in.
- Access to this repository, either through GitHub or a local checkout.
- A new Claude Code session after installing the plugin, so the slash commands and skills are loaded fresh.

## Install from the Marketplace

```bash
/plugin marketplace add sentdm/agent-skills
/plugin install sent-skills@sent-skills
```

If your SSH configuration blocks the marketplace clone, add the repository with HTTPS:

```bash
/plugin marketplace add https://github.com/sentdm/agent-skills.git
/plugin install sent-skills@sent-skills
```

## Install from a Local Checkout

```bash
git clone https://github.com/sentdm/agent-skills.git ~/dev/sent-agent-skills
```

Then run this inside Claude Code:

```bash
/plugin marketplace add file:///Users/$USER/dev/sent-agent-skills
/plugin install sent-skills@sent-skills
```

Use the real absolute path if your checkout lives somewhere else.

## Verify the Install

Run:

```bash
/plugin list
```

`sent-skills` should appear in the installed plugins list. In a fresh session, run:

```bash
/sent
```

The dispatcher should list the seven domain skills and route by intent.

## First Task

Run:

```text
/waba-template
Author a WhatsApp utility template for a shipping notification.
The package shipped today, includes a tracking link, and should avoid marketing language.
```

A good response should use `sent-skills:waba-template-author`, classify the template as utility, produce template copy with placeholders, and flag any review risks.

## Skill Activation in Claude Code

When a skill activates, Claude Code loads the matching `SKILL.md` into context for that turn. For this repo, the activation signal is usually one of:

- A slash command, such as `/waba-template` or `/mdr-analyze`.
- A natural-language request that matches the skill description, such as "why was this WhatsApp template rejected?"

Use `/context` if you need to confirm which plugin or skill files are currently loaded.

## Where to Go Next

- [`sent-skills:sms-10dlc-registration`](../skills/sms-10dlc-registration/SKILL.md) for TCR brand + campaign registration and 10DLC throughput debugging.
- [`sent-skills:waba-template-author`](../skills/waba-template-author/SKILL.md) for WhatsApp template authoring, category review, and rejection analysis.
- [`sent-skills:waba-embedded-signup`](../skills/waba-embedded-signup/SKILL.md) for Meta Embedded Signup, OAuth, and `config_id` debugging.
- [`sent-skills:rcs-agent-onboarding`](../skills/rcs-agent-onboarding/SKILL.md) for RBM agent creation, verification, and SMS fallback strategy.
- [`sent-skills:messaging-performance-analyzer`](../skills/messaging-performance-analyzer/SKILL.md) for unified Message Delivery Report analysis across SMS, WhatsApp, and RCS.
- [`sent-skills:sender-profile-architect`](../skills/sender-profile-architect/SKILL.md) for Sender Profile tenancy and cross-channel webhook routing.
- [`sent-skills:template-builder-ui`](../skills/template-builder-ui/SKILL.md) for the tenant-facing WhatsApp template builder workflow.
