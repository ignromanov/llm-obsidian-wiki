#!/bin/bash
set -euo pipefail

# Usage: section-browse.sh <vault_path> <section>
# Lists all pages in a wiki section with title + tldr.
# Format: [section]\nkey=value, then [pages]\npath | title | tldr per page.

VAULT_PATH="${1:?Usage: section-browse.sh <vault_path> <section>}"
SECTION="${2:?Usage: section-browse.sh <vault_path> <section>}"

OBS_VAULT=$(awk '/^vault_name:/{print $2}' "${VAULT_PATH}/wiki.config.md" 2>/dev/null)
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

files=$(obsidian vault="$OBS_VAULT" files folder="wiki/$SECTION" < /dev/null 2>/dev/null | grep -v '/_hub\.md$' | sort || true)

if [[ -z "$files" ]]; then
  echo "[section]"
  echo "name=$SECTION"
  echo "count=0"
  exit 0
fi

count=$(echo "$files" | wc -l | tr -d ' ')

echo "[section]"
echo "name=$SECTION"
echo "count=$count"

echo ""
echo "[pages]"

while IFS= read -r filepath; do
  slug=$(basename "$filepath" .md)
  title=$(obsidian vault="$OBS_VAULT" property:read name=title path="$filepath" < /dev/null 2>/dev/null || echo "$slug")
  tldr=$(obsidian vault="$OBS_VAULT" property:read name=tldr path="$filepath" < /dev/null 2>/dev/null || echo "")
  [[ ${#tldr} -gt 150 ]] && tldr="${tldr:0:150}..."
  echo "$slug | $title | $tldr"
done <<< "$files"
