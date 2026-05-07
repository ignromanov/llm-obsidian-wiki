#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/read-yaml-key.sh
. "$SCRIPT_DIR/lib/read-yaml-key.sh"

# Args: --vault <path> --section <focus|question|decision|operation> --content <text>
VAULT_PATH=""
SECTION=""
CONTENT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --content) CONTENT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "--vault required" >&2; exit 2; }
[[ -n "$SECTION" ]] || { echo "--section required" >&2; exit 2; }
[[ -n "$CONTENT" ]] || { echo "--content required" >&2; exit 2; }

case "$SECTION" in
  focus|question|decision|operation) ;;
  *) echo "section must be one of: focus|question|decision|operation" >&2; exit 2 ;;
esac

HOT_FILE="$VAULT_PATH/wiki/hot.md"
[[ -f "$HOT_FILE" ]] || { echo "hot.md missing at $HOT_FILE" >&2; exit 1; }

# Map section to header (portable: case instead of associative array for Bash 3.2)
case "$SECTION" in
  focus)     HEADER="## Current Focus" ;;
  question)  HEADER="## Open Questions" ;;
  decision)  HEADER="## Recent Decisions" ;;
  operation) HEADER="## Last Operations" ;;
esac

# Update last_updated frontmatter
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP=$(mktemp)
awk -v now="$NOW" '
  /^last_updated:/ { print "last_updated: " now; next }
  { print }
' "$HOT_FILE" > "$TMP" && mv "$TMP" "$HOT_FILE"

# Append content under the matching header
# For focus: replace single line below header (single-line section)
# For others: prepend bullet, trim to last 5 entries
TMP=$(mktemp)
in_section=0
section_count=0
MAX_BULLETS=5

while IFS= read -r line; do
  if [[ "$line" == "$HEADER" ]]; then
    in_section=1
    echo "$line" >> "$TMP"
    case "$SECTION" in
      focus)
        echo "$CONTENT" >> "$TMP"
        ;;
      *)
        echo "- $CONTENT" >> "$TMP"
        ;;
    esac
    continue
  fi

  # End-of-section detection: next ## header or EOF
  if [[ $in_section -eq 1 ]]; then
    if [[ "$line" =~ ^##[[:space:]] ]]; then
      in_section=0
      echo "$line" >> "$TMP"
      continue
    fi
    case "$SECTION" in
      focus)
        # Skip old single-line content (keep blank lines)
        if [[ -n "$line" ]]; then
          continue
        fi
        echo "$line" >> "$TMP"
        ;;
      *)
        # Pass through up to MAX_BULLETS bullets
        if [[ "$line" =~ ^-[[:space:]] ]]; then
          section_count=$((section_count + 1))
          if [[ $section_count -lt $MAX_BULLETS ]]; then
            echo "$line" >> "$TMP"
          fi
        else
          echo "$line" >> "$TMP"
        fi
        ;;
    esac
    continue
  fi

  echo "$line" >> "$TMP"
done < "$HOT_FILE"

mv "$TMP" "$HOT_FILE"
chmod 600 "$HOT_FILE"

echo "Updated hot.md [$SECTION]: $CONTENT"
