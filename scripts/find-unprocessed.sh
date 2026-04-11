#!/bin/bash
set -euo pipefail

# Usage: find-unprocessed.sh <vault_path>
# Lists raw files that don't have a corresponding wiki/sources/src-*.md.
#
# Detection: checks if any src-*.md references the raw file path
# in its sources: frontmatter via property:read.

VAULT_PATH="${1:?Usage: find-unprocessed.sh <vault_path>}"

RAW_DIR="${VAULT_PATH}/raw"
SOURCES_DIR="${VAULT_PATH}/wiki/sources"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "Error: raw/ directory not found at ${RAW_DIR}" >&2
  exit 1
fi

mkdir -p "$SOURCES_DIR"

OBS_VAULT=$(awk '/^vault_name:/{print $2}' "${VAULT_PATH}/wiki.config.md" 2>/dev/null || echo "")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# Build coverage set: all raw/ paths referenced in src-*.md sources: fields
# property:read returns YAML list items like "- [[raw/path/file.md|Name]]"
covered=$(obsidian vault="$OBS_VAULT" files folder="wiki/sources" < /dev/null 2>/dev/null \
  | grep '^wiki/sources/src-' \
  | while IFS= read -r src_path; do
      obsidian vault="$OBS_VAULT" property:read name=sources path="$src_path" < /dev/null 2>/dev/null
    done \
  | grep -o 'raw/[^]|"]*' \
  | sed 's/\.md$//' \
  | sort -u)

TOTAL=0
UNPROCESSED=0

while IFS= read -r raw_file; do
  [[ -z "$raw_file" ]] && continue
  TOTAL=$((TOTAL + 1))

  raw_no_ext="${raw_file%.md}"
  if echo "$covered" | grep -qxF "$raw_no_ext"; then
    continue
  fi

  echo "$raw_file"
  UNPROCESSED=$((UNPROCESSED + 1))

done < <(obsidian vault="$OBS_VAULT" files folder="raw" < /dev/null 2>/dev/null | grep -E '\.(md|pdf|txt)$' | sort)

echo ""
echo "${UNPROCESSED} unprocessed out of ${TOTAL} total raw files"
