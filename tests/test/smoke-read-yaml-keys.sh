#!/usr/bin/env bash
# Smoke test: lib_read_yaml_keys + lib_read_yaml_keys_bulk — multi-key, missing-key,
# malformed-frontmatter, quoted-value, and bulk (multi-file, single spawn) cases.
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/read-yaml-key.sh
. "$PLUGIN_ROOT/scripts/lib/read-yaml-key.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

FAIL=0
check() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "  PASS: $label"
  else
    echo "  FAIL: $label"
    echo "        got:  $(printf '%s' "$got" | od -c | head -2)"
    echo "        want: $(printf '%s' "$want" | od -c | head -2)"
    FAIL=1
  fi
}

# --- Fixture: well-formed frontmatter ---
cat > "$WORK/normal.md" <<'EOF'
---
sha256: abc123
raw_path: raw/external/foo.pdf
title: "Quoted Title"
author: 'Single Quoted'
---
Body text here.
---
second document
EOF

# --- lib_read_yaml_keys (single-file, multi-key) ---

out=$(lib_read_yaml_keys "$WORK/normal.md" sha256 raw_path)
check "multi-key sha256"    "$(printf '%s\n' "$out" | sed -n '1p')" "abc123"
check "multi-key raw_path"  "$(printf '%s\n' "$out" | sed -n '2p')" "raw/external/foo.pdf"

# Missing key → empty line in correct position
out=$(lib_read_yaml_keys "$WORK/normal.md" sha256 nonexistent raw_path)
check "missing-key line1"   "$(printf '%s\n' "$out" | sed -n '1p')" "abc123"
check "missing-key line2"   "$(printf '%s\n' "$out" | sed -n '2p')" ""
check "missing-key line3"   "$(printf '%s\n' "$out" | sed -n '3p')" "raw/external/foo.pdf"

# Quoted values stripped
out=$(lib_read_yaml_keys "$WORK/normal.md" title author)
check "double-quoted value" "$(printf '%s\n' "$out" | sed -n '1p')" "Quoted Title"
check "single-quoted value" "$(printf '%s\n' "$out" | sed -n '2p')" "Single Quoted"

# Unreadable file → return 1
if lib_read_yaml_keys "/nonexistent/path.md" sha256 >/dev/null 2>&1; then
  echo "  FAIL: unreadable file should return non-zero"
  FAIL=1
else
  echo "  PASS: unreadable file returns non-zero"
fi

# lib_read_yaml_key (single-key wrapper) still works
val=$(lib_read_yaml_key "$WORK/normal.md" sha256)
check "lib_read_yaml_key wrapper" "$val" "abc123"

# --- Fixture: malformed frontmatter (unquoted colon in value) → naive_scan fallback ---
cat > "$WORK/malformed.md" <<'EOF'
---
sha256: deadbeef
raw_path: raw/internal/bar: extra colon value
---
EOF

out=$(lib_read_yaml_keys "$WORK/malformed.md" sha256 raw_path)
check "malformed sha256"    "$(printf '%s\n' "$out" | sed -n '1p')" "deadbeef"
want_raw=$(printf '%s\n' "$out" | sed -n '2p')
[[ -n "$want_raw" ]] && echo "  PASS: malformed raw_path non-empty" \
  || { echo "  FAIL: malformed raw_path empty"; FAIL=1; }

# --- lib_read_yaml_keys_bulk (multi-file, single python3 spawn) ---

# Second fixture
cat > "$WORK/b.md" <<'EOF'
---
sha256: beef0042
raw_path: raw/external/b.pdf
---
EOF

# Third fixture: keys absent
cat > "$WORK/c.md" <<'EOF'
---
title: no sha here
---
EOF

bulk_out=$(printf '%s\n' "$WORK/normal.md" "$WORK/b.md" "$WORK/c.md" \
             | lib_read_yaml_keys_bulk sha256 raw_path)

line1=$(printf '%s\n' "$bulk_out" | sed -n '1p')
check "bulk line1 path"     "$(printf '%s' "$line1" | cut -f1)" "$WORK/normal.md"
check "bulk line1 sha256"   "$(printf '%s' "$line1" | cut -f2)" "abc123"
check "bulk line1 raw_path" "$(printf '%s' "$line1" | cut -f3)" "raw/external/foo.pdf"

line2=$(printf '%s\n' "$bulk_out" | sed -n '2p')
check "bulk line2 path"     "$(printf '%s' "$line2" | cut -f1)" "$WORK/b.md"
check "bulk line2 sha256"   "$(printf '%s' "$line2" | cut -f2)" "beef0042"
check "bulk line2 raw_path" "$(printf '%s' "$line2" | cut -f3)" "raw/external/b.pdf"

line3=$(printf '%s\n' "$bulk_out" | sed -n '3p')
check "bulk line3 path"           "$(printf '%s' "$line3" | cut -f1)" "$WORK/c.md"
check "bulk line3 sha256 empty"   "$(printf '%s' "$line3" | cut -f2)" ""
check "bulk line3 raw_path empty" "$(printf '%s' "$line3" | cut -f3)" ""

# Malformed file through bulk
bulk_mal=$(printf '%s\n' "$WORK/malformed.md" | lib_read_yaml_keys_bulk sha256 raw_path)
check "bulk malformed sha256" "$(printf '%s' "$bulk_mal" | cut -f2)" "deadbeef"
mal_raw=$(printf '%s' "$bulk_mal" | cut -f3)
[[ -n "$mal_raw" ]] && echo "  PASS: bulk malformed raw_path non-empty" \
  || { echo "  FAIL: bulk malformed raw_path empty"; FAIL=1; }

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "smoke-read-yaml-keys: OK"
else
  echo "smoke-read-yaml-keys: FAILED"
  exit 1
fi
