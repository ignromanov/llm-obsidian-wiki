#!/usr/bin/env bash
# v0.3.0 → v0.4.0 vault schema migration. Idempotent, backup-first.
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_LIB="$SCRIPT_DIR/../../lib"
# shellcheck source=../../lib/read-yaml-key.sh
. "$PLUGIN_LIB/read-yaml-key.sh"

VAULT_PATH=""; CONFIRM_BACKUP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --confirm-backup) CONFIRM_BACKUP=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path> [--confirm-backup]" >&2; exit 2; }
[[ -d "$VAULT_PATH" ]] || { echo "vault not found" >&2; exit 1; }

CONFIG="$VAULT_PATH/wiki.config.md"
[[ -f "$CONFIG" ]] || { echo "wiki.config.md missing" >&2; exit 1; }

CURRENT=$(lib_read_yaml_key "$CONFIG" "schema_version" || echo "")
if [[ "$CURRENT" == "0.4.0" ]]; then
  echo "Already on 0.4.0, no-op"; exit 0
fi
[[ "$CURRENT" == "0.3.0" ]] || { echo "expected 0.3.0, got $CURRENT" >&2; exit 1; }

# Backup with size check
SIZE_KB=$(du -sk "$VAULT_PATH" | awk '{print $1}')
SIZE_MB=$((SIZE_KB / 1024))
echo "Vault size: ${SIZE_MB}MB"
if [[ "$SIZE_MB" -gt 1024 && "$CONFIRM_BACKUP" -eq 0 ]]; then
  echo "Vault >1GB. Re-run with --confirm-backup (will copy to ${VAULT_PATH}.bak.v0.3.0/)" >&2
  exit 1
fi
BACKUP="${VAULT_PATH}.bak.v0.3.0"
[[ -d "$BACKUP" ]] && { echo "backup already exists: $BACKUP" >&2; exit 1; }
cp -rf "$VAULT_PATH" "$BACKUP"
echo "Backup → $BACKUP"

# Add new dirs
mkdir -p "$VAULT_PATH/wiki/_drafts" "$VAULT_PATH/wiki/contradictions" "$VAULT_PATH/wiki/_logs"

# Seed hot.md
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$VAULT_PATH/wiki/hot.md" <<HOT
---
type: _hot
last_updated: $NOW
window_size_words: 500
---

## Current Focus

## Open Questions

## Recent Decisions

## Last Operations
HOT
chmod 600 "$VAULT_PATH/wiki/hot.md"

# Bump schema_version (use awk for portability vs sed -i which differs BSD/GNU)
TMP=$(mktemp)
awk '
  /^schema_version:[[:space:]]*0\.3\.0[[:space:]]*$/ { print "schema_version: 0.4.0"; next }
  { print }
' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

# Append new sections if absent
if ! grep -q "^## Tree topology thresholds" "$CONFIG"; then
  cat >> "$CONFIG" <<'CFG'

## Tree topology thresholds
- index_max_links: 100
- hub_max_members: 15
- hub_min_to_split: 12

## Quality gates
- confidence_floor_for_synthesis: medium
- forgetting_curve_days: 90

## Privacy
- allow_cloud_capture: false
CFG
fi

# Per-page migration
LOG="$VAULT_PATH/wiki/_logs/migration-v0.4.0-$(date -u +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$LOG")"
{
  echo "# v0.3.0 → v0.4.0 migration log"
  echo "Started: $NOW"
  echo
} > "$LOG"

inject_field_if_missing() {
  local file="$1" key="$2" value="$3"
  if grep -q "^$key:" "$file"; then return 0; fi
  awk -v k="$key" -v v="$value" '
    BEGIN { count=0; injected=0 }
    /^---$/ {
      count++
      if (count == 2 && !injected) {
        print k": "v
        injected=1
      }
    }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  chmod 600 "$file"
}

infer_tier() {
  local p="$1"
  case "$p" in
    */wiki/index.md) echo 0 ;;
    */wiki/sources/*) echo 4 ;;
    */wiki/synthesis/*) echo 5 ;;
    */wiki/concepts/*|*/wiki/decisions/*|*/wiki/comparisons/*) echo 3 ;;
    *) echo 3 ;;
  esac
}

infer_cluster() {
  local p="$1" rel
  rel="${p#"$VAULT_PATH"/wiki/}"
  case "$rel" in
    sources/*|synthesis/*) echo "uncategorized" ;;
    */*) echo "${rel%%/*}" ;;
    *) echo "uncategorized" ;;
  esac
}

PAGE_COUNT=0; FIELD_COUNT=0; SKIPPED=0
while IFS= read -r page; do
  if ! grep -q '^---$' "$page" 2>/dev/null; then
    SKIPPED=$((SKIPPED + 1))
    echo "- skipped (no YAML frontmatter): ${page#"$VAULT_PATH"/}" >> "$LOG"
    continue
  fi
  PAGE_COUNT=$((PAGE_COUNT + 1))

  TIER=$(infer_tier "$page")
  CLUSTER=$(infer_cluster "$page")
  CREATED=$(lib_read_yaml_key "$page" "created" || echo "")
  [[ -n "$CREATED" ]] || CREATED=$(date -u +%Y-%m-%d)

  before=$(grep -c '^[a-z_]*:' "$page" 2>/dev/null || echo 0)
  inject_field_if_missing "$page" "tier" "$TIER"
  inject_field_if_missing "$page" "cluster" "$CLUSTER"
  inject_field_if_missing "$page" "aliases" "[]"
  inject_field_if_missing "$page" "last_verified" "$CREATED"

  TYPE=$(lib_read_yaml_key "$page" "type" || echo "")
  case "$TYPE" in
    decision)
      inject_field_if_missing "$page" "superseded_by" "null"
      inject_field_if_missing "$page" "supersedes" "null"
      ;;
    source-summary)
      inject_field_if_missing "$page" "quality" "high"
      inject_field_if_missing "$page" "captured_by" "legacy"
      ;;
    synthesis)
      inject_field_if_missing "$page" "filed_from_query" "null"
      ;;
  esac
  after=$(grep -c '^[a-z_]*:' "$page" 2>/dev/null || echo 0)
  FIELD_COUNT=$((FIELD_COUNT + after - before))
done < <(find "$VAULT_PATH/wiki" -name "*.md" -not -path "*/_drafts/*" -not -path "*/_logs/*" -type f)

{
  echo
  echo "## Summary"
  echo "- Pages migrated: $PAGE_COUNT"
  echo "- Fields added: $FIELD_COUNT"
  echo "- Pages skipped: $SKIPPED"
  echo "- Backup: $BACKUP"
} >> "$LOG"

echo
echo "Migration complete:"
echo "  Pages migrated: $PAGE_COUNT"
echo "  Fields added: $FIELD_COUNT"
echo "  Pages skipped: $SKIPPED"
echo "  Log: $LOG"
echo "  Backup: $BACKUP"
echo
echo "Recommended: invoke wiki-curator audit to validate health"
