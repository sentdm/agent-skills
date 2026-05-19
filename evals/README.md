# Skill Trigger Evals

This directory holds **trigger-quality eval cases** for every skill in `sent-skills`. Each YAML lists realistic user queries and the expected verdict — does the skill trigger, not trigger, or is the case ambiguous?

Today these evals are **manual**: you run each query against a fresh Claude Code session with this plugin installed and confirm the trigger behavior matches `expect`. The plan is to automate this in v0.4 once the harness is in place.

## Why these exist

A skill's `description` is the entire trigger surface — get it wrong and the skill either fires on the wrong query (false positive, noisy) or misses the query it was designed for (false negative, useless). These cases pin down what each description *claims* it does, so a description change is forced through a deliberate review of the cases it would break.

## Layout

```
evals/
  README.md
  <skill-name>.yaml      # one per skill in skills/
```

## Case format

```yaml
skill: <skill-name>
cases:
  - query: "<realistic user query>"
    expect: trigger | no_trigger | ambiguous
    rationale: <optional: why this verdict>
```

- `trigger` — the skill should fire on this query.
- `no_trigger` — the skill should NOT fire; usually keyword overlap with a different domain.
- `ambiguous` — the case sits on a real boundary between skills; `rationale` documents the desired routing.

Each skill has 4–6 cases: at least 2 `trigger`, at least 1 `no_trigger`, and at least 1 `ambiguous` or extra `trigger`.

## How to run

```bash
bash scripts/run-evals.sh
```

This prints every case grouped by skill. For each `trigger` / `no_trigger` query, open a fresh Claude Code session with this plugin installed, paste the query, and confirm:

- `trigger` cases: the target skill loads via the Skill tool.
- `no_trigger` cases: the target skill does NOT load.
- `ambiguous` cases: any behavior matching the rationale is acceptable.

Report mismatches as test failures against this repo.

## Pass criteria

- **100%** of `trigger` cases must trigger the target skill.
- **100%** of `no_trigger` cases must NOT trigger the target skill.
- `ambiguous` cases are observational — they document desired behavior but don't gate a pass.

## Adding or editing cases

Whenever you change a skill's `description`, update its eval YAML in the same PR. The description and its eval are one unit; drift between them is the bug these cases exist to prevent.
