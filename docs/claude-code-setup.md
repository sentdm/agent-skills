# Claude Code Setup

This page covers Claude Code-specific installation and troubleshooting for `sent-skills`.

## Marketplace Install

Inside Claude Code:

```bash
/plugin marketplace add sentdm/agent-skills
/plugin install sent-skills@sent-skills
```

If the short GitHub form fails because of SSH configuration, use HTTPS:

```bash
/plugin marketplace add https://github.com/sentdm/agent-skills.git
/plugin install sent-skills@sent-skills
```

Start a new session after install so the slash commands and skill descriptions are loaded.

## Local Plugin Install

Use this path for local development or unpublished changes.

```bash
git clone https://github.com/sentdm/agent-skills.git ~/dev/sent-agent-skills
```

For a one-off development session, start Claude Code with the local plugin directory:

```bash
claude --plugin-dir ~/dev/sent-agent-skills
```

To install the local checkout through Claude Code's plugin flow:

```bash
/plugin marketplace add file:///Users/$USER/dev/sent-agent-skills
/plugin install sent-skills@sent-skills
```

If your checkout is in a different directory, replace the `file://` URL with the absolute path to this repo.

## Troubleshooting

### SSH Errors During Marketplace Add

Use the HTTPS marketplace URL:

```bash
/plugin marketplace add https://github.com/sentdm/agent-skills.git
```

This avoids local SSH key and host alias issues.

### Plugin Does Not Appear

Run:

```bash
/plugin list
```

If `sent-skills` is missing, reinstall it:

```bash
/plugin install sent-skills@sent-skills
```

For local installs, confirm the path points to the repository root that contains `.claude-plugin/plugin.json`.

### Skill Does Not Activate

Start a fresh Claude Code session and ask with a direct trigger phrase, for example:

```text
Why was this WhatsApp template rejected?
```

or run the matching slash command:

```bash
/waba-template
```

If a slash command works but natural-language activation does not, inspect the skill description in `skills/<name>/SKILL.md` and confirm it contains the user's trigger phrase and a `Use when` clause.

### Check Context

Run:

```bash
/context
```

Use this to confirm whether the plugin, slash command, or skill body is loaded in the current session.

## Uninstall

Inside Claude Code:

```bash
/plugin uninstall sent-skills
```

If you added a local marketplace entry only for development, remove it from Claude Code's plugin marketplace list using the corresponding plugin management command in your current Claude Code version.
