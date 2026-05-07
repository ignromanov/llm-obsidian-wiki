#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

VAULT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path>" >&2; exit 2; }

# Collect all wikilinks across vault
LINKS=$(grep -rhoE '\[\[[^]]+\]\]' "$VAULT_PATH/wiki" 2>/dev/null \
  | sed 's/^\[\[//; s/\]\]$//; s/|.*$//' \
  | sort -u || true)

# Find pages with no incoming link (excluding self-links)
ORPHANS=()
while IFS= read -r page; do
  slug=$(basename "$page" .md)
  # Index, hub, hot are not orphans
  case "$slug" in
    index|hot|_hub*) continue ;;
  esac
  # Check if slug appears in any wikilink
  if ! echo "$LINKS" | grep -qFx "$slug"; then
    ORPHANS+=("$page")
  fi
done < <(find "$VAULT_PATH/wiki" -name "*.md" -not -path "*/_drafts/*" -not -path "*/_logs/*" -type f)

if [[ ${#ORPHANS[@]} -eq 0 ]]; then
  echo "No orphans found"
  exit 0
fi

echo "Found ${#ORPHANS[@]} orphan(s):"
for p in "${ORPHANS[@]}"; do
  rel="${p#"$VAULT_PATH"/}"
  echo "  - $rel"
done
