#!/usr/bin/env bash
# Usage: wiki-health.sh <vault_path>
# Outputs structured health checks: orphans, broken links, dead ends, missing tldr.
# Exit code: 0 = all clear, 1 = issues found.
# Format: [section]\nkey=value — designed for LLM agent consumption.
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH="${1:?Usage: wiki-health.sh <vault_path>}"

if [[ ! -d "${VAULT_PATH}/wiki" ]]; then
  echo "Error: wiki/ not found at ${VAULT_PATH}" >&2
  exit 1
fi

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

issues=0

# --- Counts ---
echo "[counts]"

orphans=$(obsidian vault="$OBS_VAULT" orphans total < /dev/null 2>/dev/null || echo "0")
orphans="${orphans:-0}"
[[ "$orphans" =~ ^[0-9]+$ ]] || orphans=0
echo "orphans=$orphans"
[[ "$orphans" -gt 0 ]] && issues=1

unresolved=$(obsidian vault="$OBS_VAULT" unresolved total < /dev/null 2>/dev/null || echo "0")
unresolved="${unresolved:-0}"
[[ "$unresolved" =~ ^[0-9]+$ ]] || unresolved=0
echo "unresolved=$unresolved"
[[ "$unresolved" -gt 0 ]] && issues=1

deadends=$(obsidian vault="$OBS_VAULT" deadends total < /dev/null 2>/dev/null || echo "0")
deadends="${deadends:-0}"
[[ "$deadends" =~ ^[0-9]+$ ]] || deadends=0
echo "deadends=$deadends"
[[ "$deadends" -gt 0 ]] && issues=1

tldr_count=$(obsidian vault="$OBS_VAULT" properties name=tldr folder=wiki total < /dev/null 2>/dev/null || echo "0")
tldr_count="${tldr_count:-0}"
[[ "$tldr_count" =~ ^[0-9]+$ ]] || tldr_count=0

wiki_count=$(obsidian vault="$OBS_VAULT" files folder=wiki total < /dev/null 2>/dev/null || echo "0")
wiki_count="${wiki_count:-0}"
[[ "$wiki_count" =~ ^[0-9]+$ ]] || wiki_count=0

missing_tldr=$((wiki_count - tldr_count))
[[ "$missing_tldr" -lt 0 ]] && missing_tldr=0
echo "missing_tldr=$missing_tldr"
[[ "$missing_tldr" -gt 0 ]] && issues=1

# --- Tag hygiene: tags used only once ---
singleton_tags=$(obsidian vault="$OBS_VAULT" tags sort=count counts < /dev/null 2>/dev/null | awk -F'\t' '$2 == 1' | wc -l | tr -d ' ')
singleton_tags="${singleton_tags:-0}"
[[ "$singleton_tags" =~ ^[0-9]+$ ]] || singleton_tags=0
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
