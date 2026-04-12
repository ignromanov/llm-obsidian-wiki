#!/usr/bin/env bash
# Usage: regenerate.sh <vault_path>
# Regenerates index.md and all _hub.md files.
# Wrapper for update-index.sh + update-hubs.sh.
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

VAULT_PATH="${1:?Usage: regenerate.sh <vault_path>}"

echo "[regenerate]"

"$SCRIPT_DIR/update-index.sh" "$VAULT_PATH" 2>&1 | tail -1
"$SCRIPT_DIR/update-hubs.sh" "$VAULT_PATH" 2>&1 | tail -1

echo "done=true"
