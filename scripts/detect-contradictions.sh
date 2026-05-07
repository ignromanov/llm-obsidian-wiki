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

TMPLIST=$(mktemp)
trap 'rm -f "$TMPLIST"' EXIT

while IFS= read -r page; do
  awk -v file="$page" '
    /^---$/ && in_yaml { in_yaml=0; next }
    /^---$/ && !in_yaml { in_yaml=1; next }
    in_yaml && /^relations:/ { in_rel=1; next }
    in_yaml && in_rel && /^[a-z_]+:/ { in_rel=0 }
    in_yaml && in_rel && /type: contradicts/ { rel_block=1 }
    in_yaml && in_rel && rel_block && /target:/ {
      gsub(/.*target: */, "")
      gsub(/[\[\]" ]/, "")
      print file ":" $0
      rel_block=0
    }
  ' "$page"
done < <(find "$VAULT_PATH/wiki" -name "*.md" -not -path "*/_drafts/*" -not -path "*/_logs/*" -type f) > "$TMPLIST"

COUNT=$(wc -l < "$TMPLIST" | tr -d ' ')
if [[ "$COUNT" -eq 0 ]]; then
  echo "No contradictions declared"
  exit 0
fi

echo "Found $COUNT declared contradiction(s):"
while IFS=: read -r src target; do
  rel_src="${src#"$VAULT_PATH"/}"
  echo "  - $rel_src contradicts $target"
done < "$TMPLIST"
