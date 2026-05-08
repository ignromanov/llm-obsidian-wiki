#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/read-yaml-key.sh
. "$SCRIPT_DIR/lib/read-yaml-key.sh"

# Args: --vault <path> --hub <slug-or-path> [--threshold N] [--apply|--dry-run]
VAULT_PATH=""; HUB=""; THRESHOLD=15; MODE="dry-run"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --hub) HUB="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --apply) MODE="apply"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" && -n "$HUB" ]] || { echo "Usage: $0 --vault <p> --hub <slug>" >&2; exit 2; }

HUB_PATH=$(find "$VAULT_PATH/wiki" -name "${HUB}.md" -type f | head -n 1)
[[ -f "$HUB_PATH" ]] || { echo "hub not found: $HUB" >&2; exit 1; }

# Extract members: lines like `- [[member-slug]]` or `[[member-slug]]`
MEMBERS=()
while IFS= read -r line; do
  if [[ "$line" =~ \[\[([^]]+)\]\] ]]; then
    MEMBERS+=("${BASH_REMATCH[1]}")
  fi
done < "$HUB_PATH"

count=${#MEMBERS[@]}
echo "Hub $HUB has $count members"
[[ $count -gt $THRESHOLD ]] || { echo "below threshold ($THRESHOLD), no split"; exit 0; }

# Topical split: by first letter of member slug. Bash 3.2: use parallel arrays
# instead of associative array. Buckets are: a-i, j-r, s-z.
BUCKET_AI=""
BUCKET_JR=""
BUCKET_SZ=""
for m in "${MEMBERS[@]}"; do
  prefix=$(echo "$m" | cut -c1 | tr '[:upper:]' '[:lower:]')
  case "$prefix" in
    [a-i]) BUCKET_AI="$BUCKET_AI $m" ;;
    [j-r]) BUCKET_JR="$BUCKET_JR $m" ;;
    *)     BUCKET_SZ="$BUCKET_SZ $m" ;;
  esac
done

bucket_get() {
  case "$1" in
    a-i) echo "$BUCKET_AI" ;;
    j-r) echo "$BUCKET_JR" ;;
    s-z) echo "$BUCKET_SZ" ;;
  esac
}

ACTIVE_BUCKETS=()
for b in a-i j-r s-z; do
  contents=$(bucket_get "$b")
  if [[ -n "$contents" ]]; then
    ACTIVE_BUCKETS+=("$b")
  fi
done

if [[ "$MODE" == "dry-run" ]]; then
  echo "Proposed split:"
  for b in "${ACTIVE_BUCKETS[@]}"; do
    echo "  $HUB-$b:$(bucket_get "$b")"
  done
  echo "Run with --apply to execute."
  exit 0
fi

# Apply: create sub-hubs, update original to point to them
HUB_DIR=$(dirname "$HUB_PATH")
for b in "${ACTIVE_BUCKETS[@]}"; do
  SUB_HUB="$HUB_DIR/${HUB}-${b}.md"
  cat > "$SUB_HUB" <<HEADER
---
type: _hub
title: ${HUB} (${b})
parent_hub: [[${HUB}]]
created: $(date -u +%Y-%m-%d)
---

# ${HUB} — ${b}

HEADER
  for m in $(bucket_get "$b"); do
    echo "- [[$m]]" >> "$SUB_HUB"
  done
  chmod 600 "$SUB_HUB"
done

# Rewrite original hub to point to sub-hubs
TMP=$(mktemp)
{
  echo "---"
  echo "type: _hub"
  echo "title: $HUB"
  echo "last_split: $(date -u +%Y-%m-%d)"
  grep -E '^(created|cluster|tier|aliases):' "$HUB_PATH" || true
  echo "---"
  echo
  echo "# $HUB"
  echo
  echo "Split into sub-hubs:"
  for b in "${ACTIVE_BUCKETS[@]}"; do
    echo "- [[${HUB}-${b}]]"
  done
} > "$TMP"
mv "$TMP" "$HUB_PATH"

echo "Split applied: ${#ACTIVE_BUCKETS[@]} sub-hubs created"
