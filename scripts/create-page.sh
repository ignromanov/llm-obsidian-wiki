#!/bin/bash
set -euo pipefail

# Usage: create-page.sh <type> <title> [vault_path]
# Creates a wiki page from template with pre-filled frontmatter.
# Does NOT overwrite existing files.

TYPE="${1:?Usage: create-page.sh <type> <title> [vault_path]}"
TITLE="${2:?Usage: create-page.sh <type> <title> [vault_path]}"
VAULT="${3:-.}"
TODAY=$(date +%Y-%m-%d)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# Validate type
TEMPLATE="${TEMPLATE_DIR}/${TYPE}.md"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: unknown type '${TYPE}'. Available:" >&2
  ls "$TEMPLATE_DIR" | sed 's/\.md$//' >&2
  exit 1
fi

# Generate slug from title
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | sed 's/  */ /g' | sed 's/ /-/g' | head -c 80)
[[ -z "$SLUG" ]] && SLUG="untitled-$(date +%s)"

# Map type to directory
case "$TYPE" in
  concept) DIR="concepts" ;;
  entity) DIR="entities" ;;
  decision) DIR="decisions" ;;
  org) DIR="orgs" ;;
  comparison) DIR="comparisons" ;;
  source-summary) DIR="sources" ;;
  open-question) DIR="open-questions" ;;
  *) DIR="$TYPE" ;;
esac

OUTPUT="${VAULT}/wiki/${DIR}/${SLUG}.md"

# Safety: never overwrite
if [[ -f "$OUTPUT" ]]; then
  echo "Error: file already exists: ${OUTPUT}" >&2
  echo "Use a different title or edit the existing file." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

# Copy template and substitute placeholders
sed "s/{{TITLE}}/${TITLE}/g; s/{{DATE}}/${TODAY}/g" "$TEMPLATE" > "$OUTPUT"

echo "$OUTPUT"
