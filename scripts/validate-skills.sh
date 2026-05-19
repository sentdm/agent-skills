#!/bin/bash
# Validate every skills/<name>/SKILL.md against the Anthropic Agent Skills spec
# and this repo's conventions.
#
# Checks:
#   1. SKILL.md exists in each skill dir
#   2. YAML frontmatter is present (--- ... ---)
#   3. `name:` field matches the directory name
#   4. `name:` matches ^[a-z0-9-]{1,64}$ and is not "anthropic" or "claude"
#   5. `description:` is present, non-empty, and <= 1024 chars
#   6. `description:` contains "Use when" (or "use when") to signal trigger conditions
#   7. SKILL.md body (after frontmatter) is <= 500 lines

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
errors=0
checked=0

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: skills/ directory not found at $SKILLS_DIR" >&2
  exit 1
fi

fail() {
  echo "  ✗ $1" >&2
  errors=$((errors + 1))
}

ok() {
  echo "  ✓ $1"
}

for skill_dir in "$SKILLS_DIR"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  checked=$((checked + 1))

  echo "Validating skills/$skill_name/"

  # 1. SKILL.md exists
  if [ ! -f "$skill_md" ]; then
    fail "SKILL.md missing"
    continue
  fi
  ok "SKILL.md present"

  # 2. Frontmatter present
  first_line="$(head -n 1 "$skill_md")"
  if [ "$first_line" != "---" ]; then
    fail "SKILL.md does not start with frontmatter delimiter '---'"
    continue
  fi
  # Find closing ---
  fm_end="$(awk 'NR>1 && /^---$/ {print NR; exit}' "$skill_md")"
  if [ -z "$fm_end" ]; then
    fail "SKILL.md frontmatter is not closed with '---'"
    continue
  fi
  ok "frontmatter delimited"

  frontmatter="$(sed -n "2,$((fm_end - 1))p" "$skill_md")"

  # 3. name matches dir name
  name_value="$(echo "$frontmatter" | awk -F': *' '/^name: */ {print $2; exit}' | tr -d '"' | tr -d "'" | tr -d '[:space:]')"
  if [ -z "$name_value" ]; then
    fail "frontmatter missing 'name'"
  elif [ "$name_value" != "$skill_name" ]; then
    fail "frontmatter name '$name_value' does not match directory '$skill_name'"
  else
    ok "name matches directory"
  fi

  # 4. name regex + reserved words
  if [ -n "$name_value" ]; then
    if ! echo "$name_value" | grep -Eq '^[a-z0-9-]{1,64}$'; then
      fail "name '$name_value' must match ^[a-z0-9-]{1,64}$"
    fi
    if [ "$name_value" = "anthropic" ] || [ "$name_value" = "claude" ]; then
      fail "name '$name_value' is a reserved word"
    fi
  fi

  # 5. description present, non-empty, <= 1024 chars
  # Extract the description value, which may span multiple lines until the next key or end of frontmatter.
  description_value="$(echo "$frontmatter" | awk '
    /^description: */ { sub(/^description: */, ""); buf=$0; in_desc=1; next }
    in_desc && /^[a-zA-Z_-]+: / { in_desc=0 }
    in_desc { buf = buf " " $0 }
    END { gsub(/^[[:space:]]+|[[:space:]]+$/, "", buf); print buf }
  ')"
  if [ -z "$description_value" ]; then
    fail "frontmatter missing or empty 'description'"
  else
    desc_len=${#description_value}
    if [ "$desc_len" -gt 1024 ]; then
      fail "description is $desc_len chars (max 1024)"
    else
      ok "description present ($desc_len chars)"
    fi

    # 6. "Use when" trigger present
    if ! echo "$description_value" | grep -iq "use when"; then
      fail "description should include at least one 'Use when …' trigger phrase"
    else
      ok "description has 'Use when' trigger"
    fi
  fi

  # 7. Body length <= 500 lines
  body_lines=$(awk -v end="$fm_end" 'NR > end' "$skill_md" | wc -l | tr -d ' ')
  if [ "$body_lines" -gt 500 ]; then
    fail "SKILL.md body is $body_lines lines (max 500); move detail to references/"
  else
    ok "body is $body_lines lines"
  fi
done

echo ""
if [ "$checked" -eq 0 ]; then
  echo "No skills found under $SKILLS_DIR" >&2
  exit 1
fi

if [ "$errors" -gt 0 ]; then
  echo "FAIL: $errors error(s) across $checked skill(s)" >&2
  exit 1
fi

echo "OK: $checked skill(s) validated"
