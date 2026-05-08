#!/usr/bin/env bash
# End-to-end smoke test: copy v0.3.0 fixture, run migration, assert results, verify idempotency.
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/v0.3.0-vault"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[[ -d "$FIXTURE" ]] || { echo "FAIL: fixture vault missing at $FIXTURE"; exit 1; }

# Copy fixture, replace placeholder
cp -rf "$FIXTURE" "$WORK/vault"
TMPCFG=$(mktemp)
sed "s|REPLACE_AT_RUNTIME|$WORK/vault|" "$WORK/vault/wiki.config.md" > "$TMPCFG"
mv "$TMPCFG" "$WORK/vault/wiki.config.md"

# Run migration
"$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh" --vault "$WORK/vault"

# --- Assertions ---

# schema_version bumped
grep -q '^schema_version: 0.4.0' "$WORK/vault/wiki.config.md" \
  || { echo "FAIL: schema_version not bumped"; exit 1; }

# New dirs
[[ -d "$WORK/vault/wiki/_drafts" ]]        || { echo "FAIL: _drafts missing"; exit 1; }
[[ -d "$WORK/vault/wiki/contradictions" ]] || { echo "FAIL: contradictions missing"; exit 1; }
[[ -d "$WORK/vault/wiki/_logs" ]]          || { echo "FAIL: _logs missing"; exit 1; }

# hot.md
[[ -f "$WORK/vault/wiki/hot.md" ]] || { echo "FAIL: hot.md missing"; exit 1; }
grep -q '^type: _hot' "$WORK/vault/wiki/hot.md" || { echo "FAIL: hot.md missing frontmatter"; exit 1; }

# Backup
[[ -d "$WORK/vault.bak.v0.3.0" ]] || { echo "FAIL: backup missing"; exit 1; }

# tier injected on concept
grep -q '^tier:' "$WORK/vault/wiki/concepts/clerk.md" \
  || { echo "FAIL: tier not injected on concept"; exit 1; }

# cluster injected
grep -q '^cluster:' "$WORK/vault/wiki/concepts/clerk.md" \
  || { echo "FAIL: cluster not injected"; exit 1; }

# last_verified injected
grep -q '^last_verified:' "$WORK/vault/wiki/concepts/clerk.md" \
  || { echo "FAIL: last_verified not injected"; exit 1; }

# Decision-specific fields
grep -q '^superseded_by: null$' "$WORK/vault/wiki/decisions/clerk-for-side-projects.md" \
  || { echo "FAIL: superseded_by not added to decision"; exit 1; }
grep -q '^supersedes: null$' "$WORK/vault/wiki/decisions/clerk-for-side-projects.md" \
  || { echo "FAIL: supersedes not added to decision"; exit 1; }

# Source-summary fields
grep -q '^quality: high$' "$WORK/vault/wiki/sources/clerk-docs.md" \
  || { echo "FAIL: quality not added to source-summary"; exit 1; }
grep -q '^captured_by: legacy$' "$WORK/vault/wiki/sources/clerk-docs.md" \
  || { echo "FAIL: captured_by not added to source-summary"; exit 1; }

# Synthesis-specific field
grep -q '^filed_from_query: null$' "$WORK/vault/wiki/synthesis/auth-decision-2026.md" \
  || { echo "FAIL: filed_from_query not added to synthesis"; exit 1; }

# Config sections appended
grep -q '^## Tree topology thresholds' "$WORK/vault/wiki.config.md" \
  || { echo "FAIL: tree topology section missing in config"; exit 1; }
grep -q '^- forgetting_curve_days:' "$WORK/vault/wiki.config.md" \
  || { echo "FAIL: forgetting_curve_days missing in config"; exit 1; }

# Migration log written
log_count=$(find "$WORK/vault/wiki/_logs" -name "migration-v0.4.0-*.md" | wc -l | tr -d ' ')
[[ "$log_count" -ge 1 ]] || { echo "FAIL: no migration log written"; exit 1; }

# Idempotency: re-run is no-op
out=$("$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh" --vault "$WORK/vault" 2>&1 || true)
echo "$out" | grep -q "Already on 0.4.0" \
  || { echo "FAIL: re-run not idempotent"; echo "$out"; exit 1; }

# Idempotency: existing fields not duplicated
duplicate_tier=$(grep -c '^tier:' "$WORK/vault/wiki/concepts/clerk.md" | tr -d ' ')
[[ "$duplicate_tier" == "1" ]] || { echo "FAIL: tier appeared $duplicate_tier times after re-run"; exit 1; }

# md5 idempotency: content identical before and after a second re-run
md5_before=$(find "$WORK/vault/wiki" -name "*.md" | sort | xargs cat | md5sum | awk '{print $1}')
"$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh" --vault "$WORK/vault" >/dev/null 2>&1 || true
md5_after=$(find "$WORK/vault/wiki" -name "*.md" | sort | xargs cat | md5sum | awk '{print $1}')
[[ "$md5_before" == "$md5_after" ]] \
  || { echo "FAIL: md5 changed after idempotent re-run"; exit 1; }

# Backup file count matches fixture wiki .md count
fixture_md_count=$(find "$PLUGIN_ROOT/tests/fixtures/v0.3.0-vault/wiki" -name "*.md" | wc -l | tr -d ' ')
backup_md_count=$(find "$WORK/vault.bak.v0.3.0/wiki" -name "*.md" | wc -l | tr -d ' ')
[[ "$fixture_md_count" -eq "$backup_md_count" ]] \
  || { echo "FAIL: backup has $backup_md_count wiki .md files, fixture has $fixture_md_count"; exit 1; }

# Per-page YAML validation: every well-formed wiki/*.md must have all four base
# fields in frontmatter after migration (excluding _logs, _drafts, hot.md, and
# pages that were intentionally malformed — those are skipped by the migrator).
while IFS= read -r page; do
  # Skip pages that lack a valid frontmatter block (migrator skips these too)
  delim_count=$(grep -c '^---$' "$page" | tr -d ' ')
  [[ "$delim_count" -ge 2 ]] || continue
  for field in tier cluster aliases last_verified; do
    found=$(awk -v key="^${field}:" '
      /^---$/ { c++; if (c == 2) exit }
      c == 1 && $0 ~ key { found=1; exit }
      END { print found+0 }
    ' "$page")
    [[ "$found" == "1" ]] \
      || { echo "FAIL: $page missing frontmatter field '$field' after migration"; exit 1; }
  done
done < <(find "$WORK/vault/wiki" -name "*.md" \
           -not -path "*/_drafts/*" \
           -not -path "*/_logs/*" \
           -not -name "hot.md" \
           -type f)

echo "smoke-migrate: OK"
