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

VIOLATIONS=()

# Check index.md
INDEX="$VAULT_PATH/wiki/index.md"
if [[ -f "$INDEX" ]]; then
  LINKS=$(grep -oE '\[\[[^]]+\]\]' "$INDEX" | wc -l | tr -d ' ')
  if [[ "$LINKS" -gt "$INDEX_MAX" ]]; then
    VIOLATIONS+=("P1 index.md: $LINKS links (max $INDEX_MAX) — split required")
  fi
fi

# Check each _hub
while IFS= read -r hub; do
  TYPE=$(grep -E '^type:' "$hub" | sed 's/^type: *//' | tr -d '"' || echo "")
  [[ "$TYPE" == "_hub" ]] || continue
  MEMBERS=$(grep -oE '\[\[[^]]+\]\]' "$hub" | wc -l | tr -d ' ')
  if [[ "$MEMBERS" -gt "$HUB_MAX" ]]; then
    rel="${hub#"$VAULT_PATH"/}"
    VIOLATIONS+=("P1 $rel: $MEMBERS members (max $HUB_MAX) — split required")
  fi
done < <(find "$VAULT_PATH/wiki" -name "*.md" -type f)

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
  echo "Tree topology OK (index ≤$INDEX_MAX, hubs ≤$HUB_MAX)"
  exit 0
fi

echo "Found ${#VIOLATIONS[@]} tree-topology violation(s):"
for v in "${VIOLATIONS[@]}"; do echo "  - $v"; done
exit 1
