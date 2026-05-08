#!/usr/bin/env bash
# Creates a wiki page from template with pre-filled frontmatter.
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

# Usage: create-page.sh <type> <title> [vault_path]
# Does NOT overwrite existing files.

TYPE="${1:?Usage: create-page.sh <type> <title> [vault_path]}"
TITLE="${2:?Usage: create-page.sh <type> <title> [vault_path]}"
VAULT="${3:-.}"
TODAY=$(date +%Y-%m-%d)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# Whitelist known types — unknown types exit immediately
case "$TYPE" in
  concept|entity|architecture|decision|strategy|org|comparison|open-question|source-summary|synthesis) ;;
  *) echo "ERROR: unknown type '$TYPE'" >&2; exit 2 ;;
esac

# Validate template exists for this type
TEMPLATE="${TEMPLATE_DIR}/${TYPE}.md"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: template file not found for type '${TYPE}': ${TEMPLATE}" >&2
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

# v0.4.0 placeholders
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CLUSTER="${CLUSTER:-uncategorized}"
AGENT_NAME="${AGENT_NAME:-unspecified}"

# Substitute placeholders via awk using env vars — safe against special chars in TITLE
TITLE="$TITLE" TYPE="$TYPE" CREATED="$TODAY" SLUG="$SLUG" \
CLUSTER="$CLUSTER" AGENT_NAME="$AGENT_NAME" NOW_ISO="$NOW_ISO" \
  awk '{
    gsub(/\{\{TITLE\}\}/, ENVIRON["TITLE"]);
    gsub(/\{\{TYPE\}\}/, ENVIRON["TYPE"]);
    gsub(/\{\{DATE\}\}/, ENVIRON["CREATED"]);
    gsub(/\{\{CREATED\}\}/, ENVIRON["CREATED"]);
    gsub(/\{\{SLUG\}\}/, ENVIRON["SLUG"]);
    gsub(/\{\{CLUSTER\}\}/, ENVIRON["CLUSTER"]);
    gsub(/\{\{AGENT_NAME\}\}/, ENVIRON["AGENT_NAME"]);
    gsub(/\{\{NOW_ISO8601\}\}/, ENVIRON["NOW_ISO"]);
    print
  }' "$TEMPLATE" > "$OUTPUT"

echo "$OUTPUT"
