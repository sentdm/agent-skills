# claude.ai Setup

claude.ai users can use individual skills without installing the Claude Code plugin. Upload each skill as a zip file through the Skills UI.

## Requirements

- A Claude plan that supports custom Skills, such as Pro, Max, Team, or Enterprise.
- Access to this repository.
- A browser session on claude.ai with Skills enabled under Settings.

## Package One Skill

From the repository root:

```bash
cd skills
zip -r waba-template-author.zip waba-template-author/
```

Upload `waba-template-author.zip` in claude.ai:

```text
Settings -> Features -> Skills -> Upload
```

Repeat the same pattern for any other skill directory you want to use.

## Multi-Skill Upload Workflow

Package each skill separately:

```bash
cd skills
zip -r sms-10dlc-registration.zip sms-10dlc-registration/
zip -r waba-template-author.zip waba-template-author/
zip -r waba-embedded-signup.zip waba-embedded-signup/
zip -r rcs-agent-onboarding.zip rcs-agent-onboarding/
zip -r messaging-performance-analyzer.zip messaging-performance-analyzer/
zip -r sender-profile-architect.zip sender-profile-architect/
zip -r template-builder-ui.zip template-builder-ui/
```

Upload each zip through the Skills UI. Keeping them separate preserves skill-level activation and makes updates easier.

## No-Network Caveat

Skills can tell Claude when to consult Meta or Sent documentation, but a claude.ai conversation may not have live network access. If Claude cannot browse, paste the relevant Meta docs excerpt, delivery report payload, template rejection, or API response into the conversation.

## Differences from Claude Code

- Slash commands such as `/waba-template` are Claude Code plugin commands and are not available in claude.ai.
- Ask naturally with the same trigger phrases, such as "classify this WhatsApp template" or "debug this Embedded Signup config_id issue."
- Uploading a skill zip does not install the repo-level `.claude-plugin` manifest or `.claude/commands/`.
