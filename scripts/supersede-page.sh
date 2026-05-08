#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/read-yaml-key.sh
. "$SCRIPT_DIR/lib/read-yaml-key.sh"

# Args: --vault <path> --old <slug-or-path> --new <slug-or-path>
VAULT_PATH=""; OLD=""; NEW=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --old) OLD="$2"; shift 2 ;;
    --new) NEW="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" && -n "$OLD" && -n "$NEW" ]] || {
  echo "Usage: $0 --vault <path> --old <slug> --new <slug>" >&2
  exit 2
}

resolve_page() {
  local needle="$1"
  if [[ -f "$VAULT_PATH/$needle" ]]; then
    echo "$VAULT_PATH/$needle"
  else
    find "$VAULT_PATH/wiki" -name "${needle}.md" -type f | head -n 1
  fi
}

OLD_PATH=$(resolve_page "$OLD")
NEW_PATH=$(resolve_page "$NEW")

[[ -f "$OLD_PATH" ]] || { echo "old page not found: $OLD" >&2; exit 1; }
[[ -f "$NEW_PATH" ]] || { echo "new page not found: $NEW" >&2; exit 1; }

OLD_SLUG=$(basename "$OLD_PATH" .md)
NEW_SLUG=$(basename "$NEW_PATH" .md)

inject_field() {
  local file="$1" key="$2" value="$3"
  if grep -q "^$key:" "$file"; then
    awk -v k="$key" -v v="$value" '
      $0 ~ "^"k":" { print k": "v; next }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  else
    awk -v k="$key" -v v="$value" '
      /^---$/ && !injected && NR > 1 { print k": "v; injected=1 }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}

inject_field "$OLD_PATH" "superseded_by" "[[$NEW_SLUG]]"
inject_field "$OLD_PATH" "status" "superseded"
inject_field "$NEW_PATH" "supersedes" "[[$OLD_SLUG]]"

echo "Marked: $OLD_SLUG superseded_by $NEW_SLUG"
