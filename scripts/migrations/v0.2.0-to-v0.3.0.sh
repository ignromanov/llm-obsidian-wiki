#!/usr/bin/env bash
# Migration: v0.2.0 → v0.3.0
# Adds: vault_path to wiki.config.md
# Rationale: v0.3.0 requires BOTH vault_name (obsidian CLI) AND vault_path (bash scripts)
# Idempotent: skips if vault_path already present
# Usage: v0.2.0-to-v0.3.0.sh <vault_path> [--dry-run]
# Exit codes: 0 = success, 1 = failure
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

usage() {
  cat >&2 <<EOF
Usage: $(basename -- "${BASH_SOURCE[0]}") <vault_path> [--dry-run]

  vault_path   Absolute path to the vault root (contains wiki.config.md)
  --dry-run    Print planned changes without applying them
EOF
  exit "${1:-1}"
}

DRY_RUN=false
VAULT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage 0 ;;
    --) shift; break ;;
    -*) echo "Error: unknown option: $1" >&2; usage 1 ;;
    *)
      [[ -z "$VAULT" ]] || { echo "Error: unexpected argument: $1" >&2; usage 1; }
      VAULT="$1"; shift
      ;;
  esac
done

[[ -n "$VAULT" ]] || { echo "Error: vault_path is required" >&2; usage 1; }

CONFIG="${VAULT}/wiki.config.md"

[[ -f "$CONFIG" ]] || { echo "Error: wiki.config.md not found at ${VAULT}" >&2; exit 1; }

echo "=== Migration v0.2.0 → v0.3.0 ==="
echo ""

# --- Add vault_path: if missing ---
if grep -q '^vault_path:' "$CONFIG"; then
  echo "[SKIP] vault_path already present in wiki.config.md"
else
  # Resolve to canonical absolute path (no symlinks, no trailing slash)
  CANON_VAULT="$(cd -- "$VAULT" && pwd -P)"
  if $DRY_RUN; then
    echo "[APPLY] would add vault_path: ${CANON_VAULT} (after vault_name line)"
  else
    # sed -i.bak is cross-platform (macOS requires backup extension; rm cleans it)
    sed -i.bak "/^vault_name:/a\\
vault_path: ${CANON_VAULT}" "$CONFIG" && rm -f "${CONFIG}.bak"
    echo "[APPLY] vault_path: ${CANON_VAULT} → wiki.config.md"
  fi
fi

echo ""
echo "=== Migration complete ==="
