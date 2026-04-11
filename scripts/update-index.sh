#!/bin/bash
set -euo pipefail

# Usage: update-index.sh <vault_path>
# Regenerates index.md from wiki pages using Obsidian CLI (property:read for tldr).
# Compatible with macOS bash 3.2 (no associative arrays).

VAULT_PATH="${1:?Usage: update-index.sh <vault_path>}"
PROJECT=$(awk '/^project:/{print $2}' "${VAULT_PATH}/wiki.config.md" 2>/dev/null || echo "Wiki")
WIKI_DIR="${VAULT_PATH}/wiki"
INDEX="${VAULT_PATH}/index.md"

if [[ ! -d "$WIKI_DIR" ]]; then
  echo "Error: wiki/ directory not found at ${WIKI_DIR}" >&2
  exit 1
fi

OBS_VAULT=$(awk '/^vault_name:/{print $2}' "${VAULT_PATH}/wiki.config.md" 2>/dev/null || echo "")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# Section order: "dir:Display Name"
SECTIONS="concepts:Concepts
entities:Entities
architecture:Architecture
decisions:Decisions
strategy:Strategy
orgs:Organizations
comparisons:Comparisons
open-questions:Open Questions
sources:Source Summaries
synthesis:Synthesis"

TODAY=$(date +%Y-%m-%d)
TOTAL=0

# Count all pages first
while IFS=: read -r dir display; do
  files=$(obsidian vault="$OBS_VAULT" files folder="wiki/$dir" < /dev/null 2>/dev/null | grep -v '/_hub\.md$' || true)
  [[ -z "$files" ]] && continue
  count=$(echo "$files" | wc -l | tr -d ' ')
  TOTAL=$((TOTAL + count))
done <<< "$SECTIONS"

# Build index content
OUTPUT="---
title: ${PROJECT} Wiki Index
updated: ${TODAY}
last_ingest: ${TODAY}
status: active
page_count: ${TOTAL}
tags:
  - index
  - meta
---

# ${PROJECT} Wiki

> [!info] Wiki Entry Point
> This is the starting point for navigating the wiki.
> Updated on every ingest. LLM reads this first when answering queries.
"

while IFS=: read -r dir display; do
  files=$(obsidian vault="$OBS_VAULT" files folder="wiki/$dir" < /dev/null 2>/dev/null | grep -v '/_hub\.md$' | sort || true)
  [[ -z "$files" ]] && continue

  count=$(echo "$files" | wc -l | tr -d ' ')

  OUTPUT+="
## ${display} (${count} pages)

"

  while IFS= read -r filepath; do
    slug=$(basename "$filepath" .md)
    tldr=$(obsidian vault="$OBS_VAULT" property:read name=tldr path="$filepath" < /dev/null 2>/dev/null || echo "")
    # Truncate to ~120 chars for readability
    if [[ ${#tldr} -gt 120 ]]; then
      tldr="${tldr:0:120}"
    fi
    if [[ -n "$tldr" ]]; then
      OUTPUT+="- [[${slug}]] -- ${tldr}
"
    else
      OUTPUT+="- [[${slug}]]
"
    fi
  done <<< "$files"
done <<< "$SECTIONS"

OUTPUT+="
---

## Recent Activity

See [[log]] for the full change log.
"

printf '%s' "$OUTPUT" > "$INDEX"
echo "index.md updated: ${TOTAL} pages across 10 domains"
