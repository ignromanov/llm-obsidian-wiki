#!/usr/bin/env bash
# v0.3.0 → v0.4.0 vault schema migration. Idempotent, backup-first.
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_LIB="$SCRIPT_DIR/../../lib"
# shellcheck source=../../lib/read-yaml-key.sh
. "$PLUGIN_LIB/read-yaml-key.sh"

# ── Globals set during arg-parse, referenced in cleanup ──────────────────────
VAULT_PATH=""
BACKUP=""

# P0-4: trap ERR/INT/TERM — clean .tmp debris and print rollback hint on failure
cleanup_on_error() {
  local rc=$?
  if [[ -n "${VAULT_PATH:-}" && -d "$VAULT_PATH" ]]; then
    find "$VAULT_PATH" -name '*.tmp' -delete 2>/dev/null || true
  fi
  if [[ $rc -ne 0 && -n "${BACKUP:-}" && -d "$BACKUP" ]]; then
    cat >&2 <<EOF

Migration FAILED (exit $rc).
Restore from backup:
  mv "$VAULT_PATH" "${VAULT_PATH}.broken"
  mv "$BACKUP" "$VAULT_PATH"

Backup is at: $BACKUP
EOF
  fi
  exit $rc
}
trap cleanup_on_error ERR INT TERM

# ── Argument parsing ──────────────────────────────────────────────────────────
CONFIRM_BACKUP=0
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

# ── Precondition check (step 1) ───────────────────────────────────────────────
CURRENT=$(lib_read_yaml_key "$CONFIG" "schema_version" || echo "")
if [[ "$CURRENT" == "0.4.0" ]]; then
  echo "Already on 0.4.0, no-op"; exit 0
fi
[[ "$CURRENT" == "0.3.0" ]] || { echo "expected 0.3.0, got $CURRENT" >&2; exit 1; }

# ── Backup (step 2) ───────────────────────────────────────────────────────────
SIZE_KB=$(du -sk "$VAULT_PATH" | awk '{print $1}')
SIZE_MB=$((SIZE_KB / 1024))
echo "Vault size: ${SIZE_MB}MB"
if [[ "$SIZE_MB" -gt 1024 && "$CONFIRM_BACKUP" -eq 0 ]]; then
  echo "Vault >1GB. Re-run with --confirm-backup (will copy to ${VAULT_PATH}.bak.v0.3.0/)" >&2
  exit 1
fi
BACKUP="${VAULT_PATH}.bak.v0.3.0"
[[ -d "$BACKUP" ]] && { echo "backup already exists: $BACKUP" >&2; exit 1; }
# P1: cp -aRf preserves symlinks-as-symlinks and file attributes
cp -aRf "$VAULT_PATH" "$BACKUP"
echo "Backup → $BACKUP"

# ── Structural additions ──────────────────────────────────────────────────────
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

# Append new config sections if absent
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

# ── Helper: check if $key exists in YAML frontmatter only (P0-1) ─────────────
yaml_has_key() {
  local file="$1" key="$2"
  awk -v key="^${key}:" '
    /^---$/ { c++; if (c == 2) exit }
    c == 1 && $0 ~ key { found = 1; exit }
    END { exit !found }
  ' "$file"
}

inject_field_if_missing() {
  local file="$1" key="$2" value="$3"
  if yaml_has_key "$file" "$key"; then return 0; fi
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

# ── Per-page migration (step 3) ───────────────────────────────────────────────
LOG="$VAULT_PATH/wiki/_logs/migration-v0.4.0-$(date -u +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$LOG")"
{
  echo "# v0.3.0 → v0.4.0 migration log"
  echo "Started: $NOW"
  echo
} > "$LOG"

PAGE_COUNT=0; FIELD_COUNT=0; SKIPPED=0; MALFORMED=0
while IFS= read -r page; do
  # P0-5: require at least two ^---$ lines (opening + closing delimiter)
  delim_count=$(grep -c '^---$' "$page" 2>/dev/null || echo 0)
  if [[ "$delim_count" -lt 2 ]]; then
    MALFORMED=$((MALFORMED + 1))
    echo "- skipped (malformed YAML, <2 delimiters): ${page#"$VAULT_PATH"/}" >> "$LOG"
    echo "  warn: skipped malformed YAML: ${page#"$VAULT_PATH"/}" >&2
    continue
  fi
  # Legacy skip-counter still increments for pages with no delimiter at all
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

  fields_before=$(grep -c '^[a-z_]*:' "$page" 2>/dev/null || echo 0)
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

  fields_after=$(grep -c '^[a-z_]*:' "$page" 2>/dev/null || echo 0)
  delta=$((fields_after - fields_before))
  FIELD_COUNT=$((FIELD_COUNT + delta))
  # P1: per-page injection log for non-zero deltas
  if [[ "$delta" -gt 0 ]]; then
    echo "- ${page#"$VAULT_PATH"/}: +${delta} fields" >> "$LOG"
  fi
done < <(find "$VAULT_PATH/wiki" -name "*.md" -not -path "*/_drafts/*" -not -path "*/_logs/*" -type f)

# ── Bump schema_version LAST, after all pages succeed (P0-3) ─────────────────
# P0-2: regex accepts both bare and quoted form: schema_version: 0.3.0 OR "0.3.0"
TMP=$(mktemp)
awk '
  /^schema_version:[[:space:]]*"?'"'"'?0\.3\.0"?'"'"'?[[:space:]]*$/ {
    print "schema_version: 0.4.0"; next
  }
  { print }
' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"

# P1: post-condition — verify the bump actually landed
NEW_VER=$(lib_read_yaml_key "$CONFIG" "schema_version" || echo "")
[[ "$NEW_VER" == "0.4.0" ]] || {
  echo "FATAL: schema_version bump failed — got '$NEW_VER' after write" >&2
  exit 1
}

# ── Write summary to log ──────────────────────────────────────────────────────
{
  echo
  echo "## Summary"
  echo "- Pages migrated: $PAGE_COUNT"
  echo "- Fields added: $FIELD_COUNT"
  echo "- Pages skipped (no frontmatter): $SKIPPED"
  echo "- Pages skipped (malformed YAML): $MALFORMED"
  echo "- Backup: $BACKUP"
} >> "$LOG"

echo
echo "Migration complete:"
echo "  Pages migrated:               $PAGE_COUNT"
echo "  Fields added:                 $FIELD_COUNT"
echo "  Pages skipped (no frontmatter): $SKIPPED"
echo "  Pages skipped (malformed YAML): $MALFORMED"
echo "  Log: $LOG"
echo "  Backup: $BACKUP"
echo
echo "Recommended: invoke wiki-curator audit to validate health"
