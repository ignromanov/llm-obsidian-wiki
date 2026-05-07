#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/read-yaml-key.sh
. "$SCRIPT_DIR/lib/read-yaml-key.sh"
# shellcheck source=lib/portable-hash.sh
. "$SCRIPT_DIR/lib/portable-hash.sh"

VAULT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path>" >&2; exit 2; }

DRIFT=()
MISSING=()

while IFS= read -r summary; do
  expected_sha=$(lib_read_yaml_key "$summary" "sha256" || echo "")
  raw_path=$(lib_read_yaml_key "$summary" "raw_path" || echo "")

  [[ -n "$expected_sha" ]] || continue
  [[ -n "$raw_path" ]] || continue

  raw_full="$VAULT_PATH/$raw_path"
  if [[ ! -f "$raw_full" ]]; then
    MISSING+=("${summary#"$VAULT_PATH"/} → raw missing: $raw_path")
    continue
  fi

  actual_sha=$(lib_sha256 "$raw_full")
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    DRIFT+=("${summary#"$VAULT_PATH"/}: expected $expected_sha, got $actual_sha")
  fi
done < <(find "$VAULT_PATH/wiki/sources" -name "*.md" -type f 2>/dev/null || true)

if [[ ${#DRIFT[@]} -eq 0 && ${#MISSING[@]} -eq 0 ]]; then
  echo "No source drift detected"
  exit 0
fi

if [[ ${#DRIFT[@]} -gt 0 ]]; then
  echo "P0 SHA drift (${#DRIFT[@]}):"
  for d in "${DRIFT[@]}"; do echo "  - $d"; done
fi
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "P0 raw missing (${#MISSING[@]}):"
  for m in "${MISSING[@]}"; do echo "  - $m"; done
fi
exit 1
