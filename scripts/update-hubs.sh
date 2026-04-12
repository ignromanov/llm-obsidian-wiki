#!/usr/bin/env bash
# Usage: update-hubs.sh <vault_path>
# Generates _hub.md in each wiki subdirectory using Obsidian CLI (property:read for title).
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH="${1:?Usage: update-hubs.sh <vault_path>}"
WIKI_DIR="${VAULT_PATH}/wiki"

if [[ ! -d "$WIKI_DIR" ]]; then
  echo "Error: wiki/ directory not found at ${WIKI_DIR}" >&2
  exit 1
fi

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
CREATED=0
UPDATED=0

for dir in "$WIKI_DIR"/*/; do
  [[ ! -d "$dir" ]] && continue

  folder=$(basename "$dir")
  hub_file="${dir}_hub.md"

  # Get files via CLI
  files=$(obsidian vault="$OBS_VAULT" files folder="wiki/$folder" < /dev/null 2>/dev/null | grep -v '/_hub\.md$' | sort || true)
  [[ -z "$files" ]] && continue

  count=$(echo "$files" | wc -l | tr -d ' ')

  # Pretty folder name
  display_name=$(echo "$folder" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  # Build page list
  page_list=""
  while IFS= read -r filepath; do
    slug=$(basename "$filepath" .md)
    title=$(obsidian vault="$OBS_VAULT" property:read name=title path="$filepath" < /dev/null 2>/dev/null || echo "$slug")
    title="${title:-$slug}"
    page_list+="- [[${slug}|${title}]]
"
  done <<< "$files"

  # Build hub content with tldr as frontmatter property
  content="---
title: \"${display_name}\"
type: hub
aliases:
  - \"${display_name}\"
  - \"${folder}\"
created: ${TODAY}
updated: ${TODAY}
tldr: \"Hub page for the **${display_name}** domain. ${count} pages.\"
---

## Pages

${page_list}"

  if [[ -f "$hub_file" ]]; then
    UPDATED=$((UPDATED + 1))
  else
    CREATED=$((CREATED + 1))
  fi
  printf '%s' "$content" > "$hub_file"

  echo "  ${folder}/ → _hub.md (${count} pages)"
done

echo ""
echo "Done: ${CREATED} created, ${UPDATED} updated"
