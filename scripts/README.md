# scripts/

Repo-wide tooling for `sent-skills`. **Per-skill scripts live under `skills/<name>/scripts/`, not here.**

## What's in this folder

Two kinds of things, both repo-wide:

- **`validate-skills.sh`** — the conformance check that every PR must pass. Validates frontmatter, name regex, "Use when" trigger, body line count. Wired into CI.
- **`run-evals.sh`** — manual eval runner (added in v0.3.0). Walks the `evals/<skill>.yaml` files and prints a checklist a human can use to spot-check trigger coverage.

Anything that operates across all skills, or against the repo as a whole, belongs here. Anything that operates on the data or artifacts of a single skill (a 10DLC packet, a WhatsApp template JSON, an MDR export) lives in that skill's own `scripts/` folder.

## Per-skill script convention

When a skill bundles an executable utility, it follows this contract:

- **Language:** Python 3.11+, **stdlib only**. No `pip install` step, no `requirements.txt`. If a script needs a third-party dependency, it doesn't ship.
- **Help flag:** every script supports `--help` and prints a one-screen usage block (purpose, args, exit codes).
- **Fixtures:** every script ships paired fixtures under `skills/<name>/scripts/fixtures/`, typically `good.json` and `bad.json`, so the script can be smoke-tested against known-good and known-bad input without leaving the repo.
- **Exit codes:** `0` on success. Non-zero with a clear stderr message on failure. No silent failures.

## How to invoke from inside a SKILL.md

When a SKILL.md body cites a script, write the path **relative to the repo root**. Claude Code resolves it via bash from the worktree root, and a human reading the skill on GitHub gets an unambiguous path they can copy-paste. Recommended prose pattern:

> Run: `python skills/<skill-name>/scripts/<script>.py <args>`

For example, from inside `skills/waba-template-author/SKILL.md`:

> Run: `python skills/waba-template-author/scripts/lint_waba_template.py path/to/template.json`

Do **not** use bare `./scripts/<script>.py` or paths relative to the SKILL.md file — those break when invoked from a different working directory.

## Currently shipped scripts (v0.3.0)

| Script | Purpose |
|---|---|
| `skills/messaging-performance-analyzer/scripts/analyze_mdr_funnel.py` | Compute MDR funnel drop-off (sent → delivered → read → replied) from a CSV export. |
| `skills/sms-10dlc-registration/scripts/validate_10dlc_packet.py` | Check 10DLC brand + campaign packet completeness before TCR submission. |
| `skills/waba-template-author/scripts/lint_waba_template.py` | Lint a WhatsApp template JSON against Meta's component + variable rules before submission. |

Eleven additional scripts are listed under "Suggested bundled references and scripts" in individual SKILL.md files and remain deferred until usage justifies them.

## Adding a new script

When bundling a new script with a skill:

- Stdlib only — no third-party imports.
- Ship `good.json` and `bad.json` fixtures next to it under `skills/<name>/scripts/fixtures/`.
- Document it in the owning SKILL.md's "Suggested bundled references and scripts" table (move it from the deferred list to the shipped list).
- Add a `--help` block.
- Ensure `bash scripts/validate-skills.sh` still exits 0 — adding a script must not regress skill conformance.

If the script operates across multiple skills or the repo as a whole, it belongs here in `scripts/` instead. Update this README so the "What's in this folder" section stays accurate.
