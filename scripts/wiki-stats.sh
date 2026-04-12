#!/usr/bin/env bash
# Usage: wiki-stats.sh <vault_path>
# Outputs structured vault metrics: totals, per-section counts, recent activity.
# Format: [section]\nkey=value — designed for LLM agent consumption.
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH="${1:?Usage: wiki-stats.sh <vault_path>}"

if [[ ! -d "${VAULT_PATH}/wiki" ]]; then
  echo "Error: wiki/ not found at ${VAULT_PATH}" >&2
  exit 1
fi

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# --- Totals ---
echo "[totals]"
echo "wiki=$(obsidian vault="$OBS_VAULT" files folder=wiki total < /dev/null 2>/dev/null)"
echo "raw=$(obsidian vault="$OBS_VAULT" files folder=raw total < /dev/null 2>/dev/null)"
echo "tags=$(obsidian vault="$OBS_VAULT" tags total < /dev/null 2>/dev/null)"

# --- Per-section counts (excluding _hub.md) ---
echo ""
echo "[sections]"
for s in concepts entities architecture decisions strategy orgs comparisons open-questions sources synthesis; do
  count=$(obsidian vault="$OBS_VAULT" files folder="wiki/$s" < /dev/null 2>/dev/null | grep -cv '/_hub\.md$' || echo 0)
  echo "$s=$count"
done

# --- Recent activity from log.md ---
echo ""
echo "[activity]"
LOG="${VAULT_PATH}/log.md"
if [[ -f "$LOG" ]]; then
  last_ingest=$(grep '^## \[' "$LOG" | grep 'ingest' | tail -1 | sed 's/^## \[\([0-9-]*\)\].*/\1/' || echo "none")
  last_lint=$(grep '^## \[' "$LOG" | grep 'lint' | tail -1 | sed 's/^## \[\([0-9-]*\)\].*/\1/' || echo "none")
  echo "last_ingest=${last_ingest:-none}"
  echo "last_lint=${last_lint:-none}"
else
  echo "last_ingest=none"
  echo "last_lint=none"
fi
