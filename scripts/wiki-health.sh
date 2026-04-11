#!/bin/bash
set -euo pipefail

# Usage: wiki-health.sh <vault_path>
# Outputs structured health checks: orphans, broken links, dead ends, missing tldr.
# Exit code: 0 = all clear, 1 = issues found.
# Format: [section]\nkey=value — designed for LLM agent consumption.

VAULT_PATH="${1:?Usage: wiki-health.sh <vault_path>}"

if [[ ! -d "${VAULT_PATH}/wiki" ]]; then
  echo "Error: wiki/ not found at ${VAULT_PATH}" >&2
  exit 1
fi

OBS_VAULT=$(awk '/^vault_name:/{print $2}' "${VAULT_PATH}/wiki.config.md" 2>/dev/null)
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

issues=0

# --- Counts ---
echo "[counts]"

orphans=$(obsidian vault="$OBS_VAULT" orphans total < /dev/null 2>/dev/null)
echo "orphans=$orphans"
[[ "$orphans" -gt 0 ]] && issues=1

unresolved=$(obsidian vault="$OBS_VAULT" unresolved total < /dev/null 2>/dev/null)
echo "unresolved=$unresolved"
[[ "$unresolved" -gt 0 ]] && issues=1

deadends=$(obsidian vault="$OBS_VAULT" deadends total < /dev/null 2>/dev/null)
echo "deadends=$deadends"
[[ "$deadends" -gt 0 ]] && issues=1

tldr_count=$(obsidian vault="$OBS_VAULT" properties name=tldr folder=wiki total < /dev/null 2>/dev/null)
wiki_count=$(obsidian vault="$OBS_VAULT" files folder=wiki total < /dev/null 2>/dev/null)
missing_tldr=$((wiki_count - tldr_count))
echo "missing_tldr=$missing_tldr"
[[ "$missing_tldr" -gt 0 ]] && issues=1

# --- Tag hygiene: tags used only once ---
singleton_tags=$(obsidian vault="$OBS_VAULT" tags sort=count counts < /dev/null 2>/dev/null | awk -F'\t' '$2 == 1' | wc -l | tr -d ' ')
echo "singleton_tags=$singleton_tags"

# --- Summary line ---
echo ""
echo "[summary]"
if [[ "$issues" -eq 0 ]]; then
  echo "status=PASS"
else
  echo "status=WARN"
fi

exit "$issues"
