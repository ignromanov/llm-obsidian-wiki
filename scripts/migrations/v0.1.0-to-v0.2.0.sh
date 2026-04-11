#!/bin/bash
set -euo pipefail

# Migration: v0.1.0 → v0.2.0
# Adds: confidence, relations, source_hashes to all wiki pages
# Idempotent: skips pages that already have the fields

VAULT="${1:?Usage: v0.1.0-to-v0.2.0.sh <vault_path>}"
WIKI_DIR="${VAULT}/wiki"
RAW_DIR="${VAULT}/raw"

if [[ ! -d "$WIKI_DIR" ]]; then
  echo "Error: wiki/ not found at ${VAULT}" >&2
  exit 1
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
    # Insert confidence after status line
    sed -i '' "/^status:/a\\
confidence: ${conf}" "$page"
    changed=true
  fi

  # --- Add relations: [] if missing ---
  if ! grep -q '^relations:' "$page"; then
    # Insert before closing ---
    close_line=$(awk '/^---$/{n++; if(n==2) {print NR; exit}}' "$page")
    if [[ -n "$close_line" ]]; then
      sed -i '' "${close_line}i\\
relations: []" "$page"
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
        raw_file="${VAULT}/${raw_rel}"
        # Ensure .md extension
        [[ "$raw_rel" != *.md ]] && raw_file="${raw_file}.md"
        if [[ -f "$raw_file" ]]; then
          hash=$(shasum -a 256 "$raw_file" | awk '{print $1}')
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
          echo "$hashes_block" > "$tmp"
          sed -i '' "$((close_line))r $tmp" "$page"
          rm -f "$tmp"
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
