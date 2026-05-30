#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/read-yaml-key.sh
. "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path>" >&2; exit 2; }

# Read forgetting_curve_days from config (default 90)
CONFIG="$VAULT_PATH/wiki.config.md"
DAYS=90
if [[ -f "$CONFIG" ]]; then
  CONFIG_DAYS=$(grep -E '^- forgetting_curve_days:' "$CONFIG" | sed 's/.*: *//' || echo "")
  [[ -n "$CONFIG_DAYS" ]] && DAYS="$CONFIG_DAYS"
fi

CUTOFF=$(($(date +%s) - DAYS * 86400))

# Collect wikilinks for orphan detection
LINKS=$(grep -rhoE '\[\[[^]]+\]\]' "$VAULT_PATH/wiki" 2>/dev/null \
  | sed 's/^\[\[//; s/\]\]$//; s/|.*$//' \
  | sort -u || true)

STALE=()

# One python3 spawn for all wiki pages via lib_read_yaml_keys_bulk.
while IFS=$'\t' read -r page last_verified updated created; do
  slug=$(basename "$page" .md)
  case "$slug" in
    index|hot|_hub*) continue ;;
  esac

  # last_verified takes precedence, then updated, then created
  last="$last_verified"
  [[ -n "$last" ]] || last="$updated"
  [[ -n "$last" ]] || last="$created"
  [[ -n "$last" ]] || continue

  # ISO date → epoch (portable: BSD then GNU)
  ts=$(date -j -f "%Y-%m-%d" "$last" +%s 2>/dev/null \
    || date -d "$last" +%s 2>/dev/null || echo "0")

  if [[ "$ts" -gt 0 && "$ts" -lt "$CUTOFF" ]]; then
    if ! echo "$LINKS" | grep -qFx "$slug"; then
      STALE+=("$page (last: $last, no incoming links)")
    fi
  fi
done < <(find "$VAULT_PATH/wiki" -name "*.md" -not -path "*/_drafts/*" -not -path "*/_logs/*" -type f \
           | lib_read_yaml_keys_bulk last_verified updated created)

if [[ ${#STALE[@]} -eq 0 ]]; then
  echo "No stale pages (threshold: $DAYS days)"
  exit 0
fi

echo "Found ${#STALE[@]} stale page(s) (older than $DAYS days, no incoming links):"
for s in "${STALE[@]}"; do echo "  - $s"; done
