#!/bin/bash
# Manual trigger-eval runner for sent-skills.
#
# Iterates evals/*.yaml and pretty-prints every case so a human can run each
# query in a fresh Claude Code session and confirm trigger behavior matches
# `expect`. Pure shell — does NOT parse YAML; just brackets each file with
# headers and cats it.
#
# Usage:
#   bash scripts/run-evals.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVALS_DIR="$REPO_ROOT/evals"

if [ ! -d "$EVALS_DIR" ]; then
  echo "ERROR: evals/ directory not found at $EVALS_DIR" >&2
  exit 1
fi

shopt -s nullglob
yamls=("$EVALS_DIR"/*.yaml)

if [ ${#yamls[@]} -eq 0 ]; then
  echo "ERROR: no eval YAML files found under $EVALS_DIR" >&2
  exit 1
fi

bar() {
  printf '=%.0s' {1..72}
  printf '\n'
}

thinbar() {
  printf -- '-%.0s' {1..72}
  printf '\n'
}

bar
echo " sent-skills trigger-eval runner"
echo " ${#yamls[@]} skill eval file(s) found in $EVALS_DIR"
bar
echo

for yaml in "${yamls[@]}"; do
  name="$(basename "$yaml" .yaml)"
  bar
  echo " SKILL: $name"
  echo " FILE:  $yaml"
  bar
  cat "$yaml"
  echo
  thinbar
  echo
done

bar
echo " HOW TO USE"
bar
cat <<'EOF'

Manually run each query in a fresh Claude Code session with this plugin
installed, then confirm the trigger behavior matches `expect`:

  - trigger     -> the target skill must load via the Skill tool.
  - no_trigger  -> the target skill must NOT load.
  - ambiguous   -> document the observed routing; behavior matching the
                   rationale is acceptable.

Report mismatches as test failures against this repo. Pass criteria and
case format live in evals/README.md.
EOF
echo
