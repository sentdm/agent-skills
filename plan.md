# sent-skills — Restructuring & Enhancement Plan

## Context

The `sent-skills` Claude Code plugin (v0.2.0) ships seven product-domain skills for SMS / WhatsApp / RCS work on [Sent](https://sent.dm). The skills were just rewritten by an external optimizer and now pass the in-repo validator cleanly: frontmatter is well-formed, descriptions hit "Use when" in third person, body sizes are 142–191 lines (well under the 500-line cap), and cross-skill references use the `sent-skills:<name>` convention.

A two-pass audit (skills + supporting infrastructure) against Anthropic's published Agent Skills best-practices doc surfaced **12 gaps** — none breaking, several high-leverage. This plan converts those gaps into four prioritized workstreams the team can ship as separate PRs.

**Out of scope.** Generic engineering skills (those belong in lifecycle repos like addyosmani/agent-skills). Mirroring Meta/Google/TCR docs into this repo. Real secrets, campaign IDs, WABA IDs, RBM agent IDs.

---

## Guiding principles

1. **Progressive disclosure is non-negotiable.** Every SKILL.md stays scannable; depth lives in `references/` and executable `scripts/`. Reference files should sit *inside the skill directory* so each skill is portable as a standalone zip.
2. **Stay product-domain.** Skill content is the messy bits of operating Sent (10DLC, WABA, RBM). Anything generic ("how to write good prompts") belongs upstream.
3. **Executable beats prose.** Where a deterministic script can replace a human checklist (template lint, 10DLC packet completeness, MDR funnel diff), ship the script.
4. **Don't break installed users.** No skill renames. No slash-command renames. Additive changes only.

---

## Open decisions (defaults marked, override during review)

| # | Question | Default | Rationale |
|---|---|---|---|
| **A** | References location: per-skill folders (`skills/<name>/references/`) vs flat top-level `references/`? | **Per-skill, with `references/sent-glossary.md` kept at top-level as a cross-cutting glossary.** | Portability — someone zipping one skill for claude.ai gets a self-contained bundle. The README already documents `cd skills && zip -r <skill>.zip <skill>/` which assumes per-skill bundling. |
| **B** | Build all ~14 missing references and ~14 scripts, or only the high-leverage ones now? | **All 14 references (prose-only, ~30 min each, unblocks progressive disclosure). 3 scripts now, defer 11.** | References are cheap and the skills already promise them. Scripts cost 2–4 hrs each plus fixture testing — ship the three with highest ROI (template lint, 10DLC validator, MDR funnel analyzer); revisit the rest once usage data justifies them. |
| **C** | Promote `/sent` router into a real `sent` skill at `skills/sent/SKILL.md`? | **Yes — make it a skill.** | The system reminder already lists `sent` as a skill. Today only users who type `/sent` get routing; making it a skill means Claude auto-invokes routing when the user asks "what can you help with on Sent?" Low cost, high UX win. |
| **D** | Rename skills to gerund form (e.g., `authoring-whatsapp-templates`)? | **No — defer indefinitely.** | Renames break shim paths, marketplace installs, user muscle memory, and external links. Document the convention for *new* skills going forward only. |

---

## Workstreams

### WS1 — Make progressive disclosure real (BLOCKING) · Effort: L

**Addresses:** G1 (refs promised but missing), G2 (refs location mismatch), G3 (orphan glossary).

**Deliverables:**
- Move the 6 single-skill references from top-level `references/` into per-skill folders (`skills/<name>/references/<topic>.md`).
- Create the **14 new reference files** that skills already cite under "Suggested bundled references" but don't exist yet.
- Keep `references/sent-glossary.md` at top-level. Link it from every SKILL.md's "Related skills" section.
- Update each SKILL.md so reference citations resolve **relative to the SKILL.md file**.

### WS2 — Ship three high-leverage executable scripts (BLOCKING) · Effort: M

**Addresses:** G4 (zero scripts shipped), G11 (script execution env undocumented).

**Deliverables:**
- `skills/waba-template-author/scripts/lint_waba_template.py` — validates template JSON before Meta submission.
- `skills/sms-10dlc-registration/scripts/validate_10dlc_packet.py` — checks compliance evidence completeness.
- `skills/messaging-performance-analyzer/scripts/analyze_mdr_funnel.py` — computes MDR funnel drop-off.
- Per-script `fixtures/` with `_good` and `_bad` examples.
- Root `scripts/README.md` documenting Python 3.11+, stdlib-only, invocation pattern.

### WS3 — Harden validator + add evals (RECOMMENDED) · Effort: M

**Addresses:** G5, G10, G12.

**Deliverables:**
- Extend `scripts/validate-skills.sh` with conservative checks (third-person, no XML, no Windows paths, vague-verb warn, extended reserved names).
- Add `evals/<skill>.yaml` for each skill with 3–5 trigger cases.
- Add `scripts/run-evals.sh` manual checklist runner.
- Add `markdown-link-check` to CI.

### WS4 — Discoverability & polish (RECOMMENDED) · Effort: S

**Addresses:** G7, G8, G9.

**Deliverables:**
- Command↔skill mapping table in README.md and CLAUDE.md.
- New `skills/sent/SKILL.md` meta-dispatcher.
- Negative trigger on `template-builder-ui`.
- Bump `plugin.json` → `0.3.0`.

---

## Per-skill change manifest

| Skill | Description tweaks | References to bundle (move ← / create ✨) | Scripts to bundle |
|---|---|---|---|
| `waba-template-author` | none | ← `waba-template-categories.md`, ✨ `waba-template-examples.md`, ✨ `template-rejection-playbook.md` | ✨ `lint_waba_template.py` |
| `sms-10dlc-registration` | none | ← `tcr-use-cases.md`, ✨ `10dlc-evidence-checklist.md`, ✨ `10dlc-rejection-remediation.md` | ✨ `validate_10dlc_packet.py` |
| `waba-embedded-signup` | none | ← `waba-embedded-signup-spec.md`, ✨ `waba-onboarding-runbook.md`, ✨ `whatsapp-sender-profile-mapping.md` | (deferred) |
| `rcs-agent-onboarding` | none | ← `rbm-agent-spec.md`, ✨ `rcs-launch-evidence-packet.md`, ✨ `rcs-fallback-patterns.md` | (deferred) |
| `messaging-performance-analyzer` | none | ← `mdr-status-codes.md`, ✨ `performance-diagnosis-playbook.md` | ✨ `analyze_mdr_funnel.py` |
| `sender-profile-architect` | none | ← `multi-tenancy-patterns.md`, ✨ `sender-profile-data-model.md`, ✨ `profile-boundary-examples.md` | (deferred) |
| `template-builder-ui` | **add negative trigger** | ✨ `template-validation-matrix.md`, ✨ `template-ui-wireflows.md`, ✨ `template-status-handling.md` | (deferred) |
| `sent` (NEW) | new frontmatter | — | — |

---

## Per-reference change manifest

| Reference filename | Action |
|---|---|
| `references/mdr-status-codes.md` | MOVE → `skills/messaging-performance-analyzer/references/` |
| `references/multi-tenancy-patterns.md` | MOVE → `skills/sender-profile-architect/references/` |
| `references/rbm-agent-spec.md` | MOVE → `skills/rcs-agent-onboarding/references/` |
| `references/tcr-use-cases.md` | MOVE → `skills/sms-10dlc-registration/references/` |
| `references/waba-embedded-signup-spec.md` | MOVE → `skills/waba-embedded-signup/references/` |
| `references/waba-template-categories.md` | MOVE → `skills/waba-template-author/references/` |
| `references/sent-glossary.md` | KEEP at top-level; cross-link from all 7 skills |
| 14 new reference files | CREATE at per-skill `references/` paths |

---

## Infrastructure changes

- **`scripts/validate-skills.sh`** — add 5 conservative checks (third-person, XML-free, no Windows paths, vague-verb warn, extended reserved names).
- **`.github/workflows/validate-skills.yml`** — add `markdown-link-check` step.
- **`CLAUDE.md`** — command↔skill mapping table; path-resolution paragraph; script invocation convention.
- **`CONTRIBUTING.md`** — eval requirement; gerund convention for new skills; per-skill `references/` rule.
- **`README.md`** — mapping table; updated layout section.
- **`docs/skill-anatomy.md`** — per-skill bundling section; eval cases section.
- **`.claude-plugin/plugin.json`** — `version` → `0.3.0`.

---

## Rollout

Executed via `/batch` as 13 parallel work units in isolated worktrees:

| # | Unit | Scope |
|---|---|---|
| 1 | `messaging-performance-analyzer` | refs + script + SKILL.md |
| 2 | `rcs-agent-onboarding` | refs + SKILL.md |
| 3 | `sender-profile-architect` | refs + SKILL.md |
| 4 | `sms-10dlc-registration` | refs + script + SKILL.md |
| 5 | `template-builder-ui` | refs + negative trigger + SKILL.md |
| 6 | `waba-embedded-signup` | refs + SKILL.md |
| 7 | `waba-template-author` | refs + script + SKILL.md |
| 8 | `scripts/README.md` | new file |
| 9 | Validator extension | `scripts/validate-skills.sh` |
| 10 | `evals/` directory | 8 YAML files + `run-evals.sh` |
| 11 | CI link check | `.github/workflows/validate-skills.yml` + config |
| 12 | `sent` meta-skill | `skills/sent/SKILL.md` |
| 13 | Docs + version bump | README, CLAUDE, CONTRIBUTING, skill-anatomy, plugin.json |

---

## Explicitly deferred

- Skill renames to gerund form.
- 11 of the 14 suggested scripts (ship when usage data justifies).
- Automated eval execution against the API.
- New product-domain skills.
- Mirroring Meta/Google/TCR docs.
