#!/usr/bin/env bash
# Migration: v0.1.0 → v0.2.0
# Adds: confidence, relations, source_hashes to all wiki pages
# Idempotent: skips pages that already have the fields
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

VAULT="${1:?Usage: v0.1.0-to-v0.2.0.sh <vault_path>}"
WIKI_DIR="${VAULT}/wiki"

if [[ ! -d "$WIKI_DIR" ]]; then
  echo "Error: wiki/ not found at ${VAULT}" >&2
  exit 1
fi

# Cross-platform sha256: prefer sha256sum (Linux/GNU), fall back to shasum (macOS/BSD)
if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD="sha256sum"
else
  HASH_CMD="shasum -a 256"
fi

TOTAL=0
MIGRATED=0
SKIPPED=0
HASH_ADDED=0

echo "=== Migration v0.1.0 → v0.2.0 ==="
echo ""

# Process all wiki pages
while IFS= read -r -d '' page; do
  [[ ! -f "$page" ]] && continue
  rel_path="${page#"${VAULT}"/}"
  TOTAL=$((TOTAL + 1))
  changed=false

  # Skip non-frontmatter files
  head -1 "$page" | grep -q '^---$' || continue

  # --- Add confidence: if missing ---
  if ! grep -q '^confidence:' "$page"; then
    # Count sources to determine confidence
    src_count=$(sed -n '/^sources:/,/^[a-z]/p' "$page" | grep -c '^\s*-' || true)
    if [[ "$src_count" -ge 3 ]]; then
      conf="high"
    elif [[ "$src_count" -ge 2 ]]; then
      conf="medium"
    else
      conf="low"
    fi
    # Insert confidence after status line; use .bak for cross-platform -i compatibility
    sed -i.bak "/^status:/a\\
confidence: ${conf}" "$page" && rm -f "${page}.bak"
    changed=true
  fi

  # --- Add relations: [] if missing ---
  if ! grep -q '^relations:' "$page"; then
    # Insert before closing ---
    close_line=$(awk '/^---$/{n++; if(n==2) {print NR; exit}}' "$page")
    if [[ -n "$close_line" ]]; then
      sed -i.bak "${close_line}i\\
relations: []" "$page" && rm -f "${page}.bak"
      changed=true
    fi
  fi

  # --- Add source_hashes: if missing ---
  if ! grep -q '^source_hashes:' "$page"; then
    # Extract raw/ paths from sources: field
    raw_paths=$(sed -n '/^sources:/,/^[a-z]/p' "$page" | grep -o 'raw/[^]|"]*' || true)

    if [[ -n "$raw_paths" ]]; then
      hashes_block="source_hashes:"
      has_hashes=false
      while IFS= read -r raw_rel; do
        [[ -z "$raw_rel" ]] && continue

        # Reject path traversal and absolute paths
        [[ "$raw_rel" != *..* && "$raw_rel" != /* ]] || {
          echo "WARN: skipping suspicious raw_rel: $raw_rel" >&2
          continue
        }

        raw_file="${VAULT}/${raw_rel}"
        # Ensure .md extension
        [[ "$raw_rel" != *.md ]] && raw_file="${raw_file}.md"
        if [[ -f "$raw_file" ]]; then
          hash=$($HASH_CMD "$raw_file" | cut -d' ' -f1)
          hashes_block+=$'\n'"  - path: \"${raw_rel}\""
          hashes_block+=$'\n'"    sha256: \"${hash}\""
          has_hashes=true
          HASH_ADDED=$((HASH_ADDED + 1))
        fi
      done <<< "$raw_paths"

      if $has_hashes; then
        close_line=$(awk '/^---$/{n++; if(n==2) {print NR; exit}}' "$page")
        if [[ -n "$close_line" ]]; then
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT
          echo "$hashes_block" > "$tmp"
          sed -i.bak "$((close_line))r $tmp" "$page" && rm -f "${page}.bak"
          rm -f "$tmp"
          trap - EXIT
          changed=true
        fi
      fi
    fi
  fi

  if $changed; then
    MIGRATED=$((MIGRATED + 1))
    echo "  MIGRATED: ${rel_path}"
  else
    SKIPPED=$((SKIPPED + 1))
  fi

done < <(find "$WIKI_DIR" -name '*.md' -not -name '_hub.md' -not -name 'index.md' -print0 | sort -z)

echo ""
echo "=== Migration complete ==="
echo "Total pages: $TOTAL"
echo "Migrated: $MIGRATED"
echo "Skipped (already current): $SKIPPED"
echo "Source hashes added: $HASH_ADDED"
