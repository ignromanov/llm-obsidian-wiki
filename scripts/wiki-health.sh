#!/usr/bin/env bash
# Aggregator: delegates to atomic check scripts and classifies findings by severity.
# Usage: wiki-health.sh --vault <path>   (also accepts positional vault path)
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VAULT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    *)
      # Backward-compat: positional vault path
      if [[ -z "$VAULT_PATH" ]]; then
        VAULT_PATH="$1"; shift; continue
      fi
      echo "Unknown arg: $1" >&2; exit 2
      ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path>" >&2; exit 2; }
[[ -d "$VAULT_PATH" ]] || { echo "vault not found: $VAULT_PATH" >&2; exit 1; }

P0=0; P1=0; P2=0

run_check() {
  local label="$1" severity="$2"
  shift 2
  echo "=== $label ==="
  if "$@"; then
    return 0
  else
    case "$severity" in
      P0) P0=$((P0 + 1)) ;;
      P1) P1=$((P1 + 1)) ;;
      P2) P2=$((P2 + 1)) ;;
    esac
  fi
}

run_check "Source drift"   "P0" bash "$SCRIPT_DIR/verify-source-drift.sh"   --vault "$VAULT_PATH"
run_check "Tree topology"  "P1" bash "$SCRIPT_DIR/verify-tree-topology.sh"  --vault "$VAULT_PATH"
run_check "Orphans"        "P2" bash "$SCRIPT_DIR/find-orphans.sh"           --vault "$VAULT_PATH"
run_check "Stale pages"    "P2" bash "$SCRIPT_DIR/detect-stale.sh"           --vault "$VAULT_PATH"
run_check "Contradictions" "P1" bash "$SCRIPT_DIR/detect-contradictions.sh" --vault "$VAULT_PATH"

echo
echo "=== Health summary ==="
echo "P0 (broken):     $P0"
echo "P1 (degraded):   $P1"
echo "P2 (suggestion): $P2"

[[ "$P0" -eq 0 ]] || exit 1
[[ "$P1" -eq 0 ]] || exit 2
exit 0
