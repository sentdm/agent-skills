#!/bin/bash
# Validate every skills/<name>/SKILL.md against the Anthropic Agent Skills spec
# and this repo's conventions.
#
# Checks:
#   1. SKILL.md exists in each skill dir
#   2. YAML frontmatter is present (--- ... ---)
#   3. `name:` field matches the directory name
#   4. `name:` matches ^[a-z0-9-]{1,64}$ and is not a reserved word
#      (anthropic, claude, meta, google)
#   5. `description:` is present, non-empty, and <= 1024 chars
#   6. `description:` contains "Use when" (or "use when") to signal trigger conditions
#   7. SKILL.md body (after frontmatter) is <= 500 lines
#   8. `description:` is in third person — no first/second-person pronouns or "can help"
#      (quoted user trigger phrases are exempt — they're verbatim quotes, not narration)
#   9. `description:` contains no XML-style angle brackets (breaks manifest parsing)
#  10. `description:` should not open with a vague verb (Helps, Manages, Tools for, …) — WARN only
#  11. Body (outside fenced code blocks) uses forward slashes, not Windows-style `\`

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
    case "$name_value" in
      anthropic|claude|meta|google)
        fail "name '$name_value' is a reserved word"
        ;;
    esac
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

  # ---------------------------------------------------------------------------
  # Conservative best-practice checks (added in v0.3).
  # Each check passes on the current 7 in-repo skills; tighten in v0.4.
  # ---------------------------------------------------------------------------

  if [ -n "$description_value" ]; then
    # 8. Description in third person.
    # Strip "quoted phrases" first — those are verbatim user triggers, not narration.
    # Case-sensitive on pronouns so "US" (country) doesn't match "us".
    desc_no_quotes="$(echo "$description_value" | sed 's/"[^"]*"//g')"
    if echo "$desc_no_quotes" | grep -qE '\b(I|you|we|us|my|your|our)\b' \
       || echo "$desc_no_quotes" | grep -qi 'can help'; then
      fail "description uses first/second person — rewrite in third person (e.g., 'Analyzes', 'Designs')"
    else
      ok "description is in third person"
    fi

    # 9. No XML-style angle brackets in description (breaks manifest parsing).
    if echo "$description_value" | grep -qE '<[a-zA-Z/]'; then
      fail "description contains XML-style tags — these break manifest parsing"
    else
      ok "description has no XML-style tags"
    fi

    # 10. (WARN, doesn't increment errors.) Description opener should be specific.
    case "$description_value" in
      "Helps "*|"Manages "*|"Tools for "*|"Utility for "*|"Provides "*)
        echo "  ⚠ description starts with vague verb — consider a more specific opener (e.g., 'Analyzes', 'Generates', 'Validates')" >&2
        ;;
    esac
  fi

  # 11. No Windows-style path separators in body (outside fenced code blocks).
  # Matches a single literal backslash — Windows paths use `dir\file`.
  body_no_code="$(awk -v end="$fm_end" 'NR > end { if ($0 ~ /^```/) { incode = !incode; next } if (!incode) print }' "$skill_md")"
  if echo "$body_no_code" | grep -q '\\'; then
    fail "body contains Windows-style path separators (\\) outside code blocks — use forward slashes"
  else
    ok "body uses forward-slash paths"
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
