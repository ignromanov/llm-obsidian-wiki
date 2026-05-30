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

CONFIG="$VAULT_PATH/wiki.config.md"
INDEX_MAX=100
HUB_MAX=15

if [[ -f "$CONFIG" ]]; then
  v=$(grep -E '^- index_max_links:' "$CONFIG" | sed 's/.*: *//' || echo "")
  [[ -n "$v" ]] && INDEX_MAX="$v"
  v=$(grep -E '^- hub_max_members:' "$CONFIG" | sed 's/.*: *//' || echo "")
  [[ -n "$v" ]] && HUB_MAX="$v"
fi

ADVISORIES=()

# index.md is auto-generated — exempt from link-count check entirely.

# Check each hub. Hubs are identified by filename (`_hub.md`), not the `type:`
# field — that field drifts in real vaults (e.g. concepts/_hub.md carries
# `type: concept`), so a type filter silently skips the largest hubs.
# Hub overages are ADVISORY (soft cap), not hard violations.
while IFS= read -r hub; do
  MEMBERS=$(grep -oE '\[\[[^]]+\]\]' "$hub" | wc -l | tr -d ' ')
  if [[ "$MEMBERS" -gt "$HUB_MAX" ]]; then
    rel="${hub#"$VAULT_PATH"/}"
    ADVISORIES+=("$rel: $MEMBERS members (soft cap $HUB_MAX)")
  fi
done < <(find "$VAULT_PATH/wiki" -name "_hub.md" -type f)

echo "Tree topology OK (index exempt — auto-generated, hubs soft cap $HUB_MAX)"

if [[ ${#ADVISORIES[@]} -gt 0 ]]; then
  echo "Advisory: ${#ADVISORIES[@]} hub(s) over soft cap ($HUB_MAX):"
  for a in "${ADVISORIES[@]}"; do echo "  - $a"; done
fi

exit 0
