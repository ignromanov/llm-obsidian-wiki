#!/usr/bin/env bash
# Usage: page-context.sh <vault_path> <page>
# Outputs full structured context for a wiki page:
#   [meta]      — title, tldr, type, status, updated, tags, aliases, sources
#   [backlinks] — inbound content links (structural files filtered), with total
#   [links]     — outbound links with total and unresolved count
# <page> is a wikilink-style name (no path, no extension), e.g. "magic-dust".
# Format: [section]\nkey=value or list — designed for LLM agent consumption.
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH="${1:?Usage: page-context.sh <vault_path> <page>}"
PAGE="${2:?Usage: page-context.sh <vault_path> <page>}"

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# Helper: read a property, join list values with ", "
read_prop() {
  local val
  val=$(obsidian vault="$OBS_VAULT" property:read name="$1" file="$PAGE" < /dev/null 2>/dev/null || echo "")
  # Join multiline (list properties) into comma-separated
  echo "$val" | paste -sd ',' - | sed 's/,/, /g'
}

# --- Page metadata ---
echo "[meta]"
echo "title=$(read_prop title)"
echo "tldr=$(read_prop tldr)"
echo "type=$(read_prop type)"
echo "status=$(read_prop status)"
echo "updated=$(read_prop updated)"
echo "tags=$(read_prop tags)"
echo "aliases=$(read_prop aliases)"
echo "sources=$(read_prop sources)"

# --- Backlinks (who links to this page) ---
# Filter structural files: index.md, log.md, _hub.md
echo ""
echo "[backlinks]"
bl_raw=$(obsidian vault="$OBS_VAULT" backlinks file="$PAGE" counts < /dev/null 2>/dev/null || echo "")
bl_filtered=$(echo "$bl_raw" | grep -v -E '(^index\.md|^log\.md|_hub\.md)' || true)
if [[ -n "$bl_filtered" ]]; then
  echo "$bl_filtered"
  bl_count=$(echo "$bl_filtered" | wc -l | tr -d ' ')
else
  bl_count=0
fi
echo "backlinks_total=$bl_count"

# --- Outgoing links (what this page links to) ---
echo ""
echo "[links]"
links_raw=$(obsidian vault="$OBS_VAULT" links file="$PAGE" < /dev/null 2>/dev/null || echo "")
if [[ -n "$links_raw" ]]; then
  echo "$links_raw"
  links_total=$(echo "$links_raw" | wc -l | tr -d ' ')
  unresolved=$(echo "$links_raw" | grep -c '(unresolved)' || true)
else
  links_total=0
  unresolved=0
fi
echo "links_total=$links_total"
echo "unresolved=$unresolved"
