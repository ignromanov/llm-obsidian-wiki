#!/usr/bin/env bash
# Edge-case smoke test for migrate.sh:
#   1. Body-key collision — tier/cluster in body must not suppress frontmatter injection
#   2. Quoted schema_version — schema_version: "0.3.0" must be bumped correctly
#   3. Malformed YAML — page missing closing --- must be skipped, not corrupted
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/v0.3.0-vault"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[[ -d "$FIXTURE" ]] || { echo "FAIL: fixture vault missing at $FIXTURE"; exit 1; }

MIGRATE="$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh"

# ── Helper ────────────────────────────────────────────────────────────────────
# Assert $key exists in YAML frontmatter (between first two ---) of $file
assert_frontmatter_has_key() {
  local file="$1" key="$2" label="$3"
  local found
  found=$(awk -v key="^${key}:" '
    /^---$/ { c++; if (c == 2) exit }
    c == 1 && $0 ~ key { found=1; exit }
    END { print found+0 }
  ' "$file")
  [[ "$found" == "1" ]] || { echo "FAIL: $label — '$key' not in frontmatter of $file"; exit 1; }
}

assert_frontmatter_not_in_body() {
  local file="$1" key="$2" label="$3"
  # Count occurrences of key: in frontmatter only
  local fm_count
  fm_count=$(awk -v key="^${key}:" '
    /^---$/ { c++; if (c == 2) exit }
    c == 1 && $0 ~ key { n++ }
    END { print n+0 }
  ' "$file")
  [[ "$fm_count" -eq 1 ]] || { echo "FAIL: $label — '$key' appears $fm_count times in frontmatter (expected 1)"; exit 1; }
}

# ── Case 1: Body-key collision ────────────────────────────────────────────────
echo "=== Case 1: body-key collision ==="
cp -aRf "$FIXTURE" "$WORK/vault1"
sed "s|REPLACE_AT_RUNTIME|$WORK/vault1|" "$WORK/vault1/wiki.config.md" > "$WORK/cfg1.tmp"
mv "$WORK/cfg1.tmp" "$WORK/vault1/wiki.config.md"

"$MIGRATE" --vault "$WORK/vault1" >/dev/null

COLLISION="$WORK/vault1/wiki/concepts/body-key-collision.md"
[[ -f "$COLLISION" ]] || { echo "FAIL: body-key-collision.md not found after migration"; exit 1; }

# tier and cluster must be in FRONTMATTER despite body lines starting with them
assert_frontmatter_has_key "$COLLISION" "tier" "body-key-collision"
assert_frontmatter_has_key "$COLLISION" "cluster" "body-key-collision"
assert_frontmatter_not_in_body "$COLLISION" "tier" "body-key-collision (no duplicate tier)"
assert_frontmatter_not_in_body "$COLLISION" "cluster" "body-key-collision (no duplicate cluster)"

# Body lines must be preserved verbatim
grep -q '^tier: this is body text' "$COLLISION" \
  || { echo "FAIL: body-key-collision — body 'tier:' line was removed or altered"; exit 1; }
grep -q '^cluster: also body text' "$COLLISION" \
  || { echo "FAIL: body-key-collision — body 'cluster:' line was removed or altered"; exit 1; }

echo "  PASS: tier and cluster injected into frontmatter despite body collision"

# ── Case 2: Quoted schema_version ─────────────────────────────────────────────
echo "=== Case 2: quoted schema_version ==="
cp -aRf "$FIXTURE" "$WORK/vault2"
# Replace bare schema_version: 0.3.0 with quoted form
sed 's/^schema_version: 0\.3\.0$/schema_version: "0.3.0"/' "$WORK/vault2/wiki.config.md" \
  | sed "s|REPLACE_AT_RUNTIME|$WORK/vault2|" > "$WORK/cfg2.tmp"
mv "$WORK/cfg2.tmp" "$WORK/vault2/wiki.config.md"

# Verify the fixture was actually modified (sanity check)
grep -q '^schema_version: "0.3.0"' "$WORK/vault2/wiki.config.md" \
  || { echo "FAIL: quoted-schema setup — sed did not produce quoted form"; exit 1; }

"$MIGRATE" --vault "$WORK/vault2" >/dev/null

# schema_version must be bumped to 0.4.0 (unquoted canonical form)
grep -q '^schema_version: 0.4.0' "$WORK/vault2/wiki.config.md" \
  || { echo "FAIL: quoted-schema — schema_version not bumped from quoted 0.3.0"; exit 1; }

echo "  PASS: quoted schema_version bumped correctly"

# ── Case 3: Malformed YAML (missing closing ---) ──────────────────────────────
echo "=== Case 3: malformed YAML page ==="
cp -aRf "$FIXTURE" "$WORK/vault3"
sed "s|REPLACE_AT_RUNTIME|$WORK/vault3|" "$WORK/vault3/wiki.config.md" > "$WORK/cfg3.tmp"
mv "$WORK/cfg3.tmp" "$WORK/vault3/wiki.config.md"

MALFORMED_SRC="$WORK/vault3/wiki/concepts/malformed.md"
[[ -f "$MALFORMED_SRC" ]] || { echo "FAIL: malformed.md fixture not found"; exit 1; }

# Capture content before migration
content_before=$(cat "$MALFORMED_SRC")

migrate_out=$("$MIGRATE" --vault "$WORK/vault3" 2>&1)

# Migration must report at least 1 malformed page
echo "$migrate_out" | grep -q "malformed YAML.*[1-9]" \
  || { echo "FAIL: malformed-yaml — migration output did not report malformed page count"; echo "$migrate_out"; exit 1; }

# The malformed file must NOT have been mutated
content_after=$(cat "$MALFORMED_SRC")
[[ "$content_before" == "$content_after" ]] \
  || { echo "FAIL: malformed-yaml — malformed.md was mutated by migration"; exit 1; }

# Migration log must reference the skipped file
log_file=$(find "$WORK/vault3/wiki/_logs" -name "migration-v0.4.0-*.md" | head -1)
grep -q "malformed" "$log_file" \
  || { echo "FAIL: malformed-yaml — migration log does not mention malformed file"; exit 1; }

echo "  PASS: malformed page skipped and logged, file unchanged"

# ── Case 4: md5 idempotency after full migration ──────────────────────────────
echo "=== Case 4: md5 idempotency ==="
# vault1 is already migrated — re-run must produce "Already on 0.4.0"
rerun_out=$("$MIGRATE" --vault "$WORK/vault1" 2>&1 || true)
echo "$rerun_out" | grep -q "Already on 0.4.0" \
  || { echo "FAIL: idempotency — re-run on vault1 did not print 'Already on 0.4.0'"; echo "$rerun_out"; exit 1; }

# md5 of all wiki/*.md before vs after a re-run attempt must be identical
md5_before=$(find "$WORK/vault1/wiki" -name "*.md" | sort | xargs cat | md5sum | awk '{print $1}')
"$MIGRATE" --vault "$WORK/vault1" >/dev/null 2>&1 || true
md5_after=$(find "$WORK/vault1/wiki" -name "*.md" | sort | xargs cat | md5sum | awk '{print $1}')
[[ "$md5_before" == "$md5_after" ]] \
  || { echo "FAIL: idempotency — wiki md5 changed after re-run"; exit 1; }

echo "  PASS: md5 stable after re-run"

# ── Case 5: backup file count matches pre-migration vault ─────────────────────
echo "=== Case 5: backup completeness ==="
pre_count=$(find "$FIXTURE/wiki" -name "*.md" | wc -l | tr -d ' ')
post_backup_count=$(find "$WORK/vault1.bak.v0.3.0/wiki" -name "*.md" | wc -l | tr -d ' ')
[[ "$pre_count" -eq "$post_backup_count" ]] \
  || { echo "FAIL: backup completeness — fixture has $pre_count wiki .md files, backup has $post_backup_count"; exit 1; }

echo "  PASS: backup contains same number of wiki .md files as fixture"

echo
echo "smoke-migrate-edge-cases: OK"
