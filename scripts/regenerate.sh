#!/bin/bash
set -euo pipefail

# Usage: regenerate.sh <vault_path>
# Regenerates index.md and all _hub.md files.
# Wrapper for update-index.sh + update-hubs.sh.

VAULT_PATH="${1:?Usage: regenerate.sh <vault_path>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[regenerate]"

"$SCRIPT_DIR/update-index.sh" "$VAULT_PATH" 2>&1 | tail -1
"$SCRIPT_DIR/update-hubs.sh" "$VAULT_PATH" 2>&1 | tail -1

echo "done=true"
