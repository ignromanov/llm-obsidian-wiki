#!/bin/bash
set -euo pipefail

# Escape string for safe YAML double-quoted value
yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash
  s="${s//\"/\\\"}"    # double quote
  echo "$s"
}

# Usage: capture-url.sh <url> <vault_path>
# Captures a web article into raw/external/ using defuddle (with pandoc fallback).

URL="${1:?Usage: capture-url.sh <url> <vault_path>}"
VAULT="${2:?Usage: capture-url.sh <url> <vault_path>}"
TODAY=$(date +%Y-%m-%d)

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 not found" >&2
  exit 1
fi

RAW_DIR="${VAULT}/raw/external"
mkdir -p "$RAW_DIR"

# --- Extract content ---

TITLE=""
AUTHOR=""
CONTENT=""

if command -v defuddle &>/dev/null; then
  JSON=$(defuddle parse "$URL" --json)
  TITLE=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
  AUTHOR=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author',''))" 2>/dev/null || echo "")
  CONTENT=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")
else
  echo "defuddle not found, falling back to curl + pandoc" >&2
  if ! command -v pandoc &>/dev/null; then
    echo "Error: neither defuddle nor pandoc found" >&2
    exit 1
  fi
  CONTENT=$(curl -sL "$URL" | pandoc -f html -t markdown)
  # Extract title from first H1 if present
  TITLE=$(echo "$CONTENT" | grep -m1 '^# ' | sed 's/^# //' || echo "")
fi

# Fallback title from URL if empty
if [[ -z "$TITLE" ]]; then
  TITLE=$(echo "$URL" | sed 's|https\?://||;s|/|-|g;s|[?#].*||')
fi

# --- Generate slug ---

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | sed 's/  */ /g' | sed 's/ /-/g' | head -c 80)

# Avoid empty slug
if [[ -z "$SLUG" ]]; then
  SLUG="capture-$(date +%s)"
fi

OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"

# Avoid overwriting existing files
if [[ -f "$OUTPUT" ]]; then
  SLUG="${SLUG}-$(date +%s)"
  OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"
fi

# --- Write file ---

{
  echo "---"
  echo "title: \"$(yaml_escape "$TITLE")\""
  echo "source_type: article"
  echo "source_url: \"${URL}\""
  echo "captured: ${TODAY}"
  if [[ -n "$AUTHOR" ]]; then
    echo "author: \"$(yaml_escape "$AUTHOR")\""
  fi
  echo "---"
  echo ""
  echo "$CONTENT"
} > "$OUTPUT"

echo "$OUTPUT"
