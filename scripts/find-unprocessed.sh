#!/usr/bin/env bash
# Usage: find-unprocessed.sh <vault_path>
# Lists raw files that don't have a corresponding wiki/sources/src-*.md.
#
# Detection: checks if any src-*.md references the raw file path
# in its sources: frontmatter via property:read.
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

VAULT_PATH="${1:?Usage: find-unprocessed.sh <vault_path>}"

RAW_DIR="${VAULT_PATH}/raw"
SOURCES_DIR="${VAULT_PATH}/wiki/sources"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "Error: raw/ directory not found at ${RAW_DIR}" >&2
  exit 1
fi

mkdir -p "$SOURCES_DIR"

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# Build coverage set: all raw/ paths referenced in src-*.md sources: fields
# property:read returns YAML list items like "- [[raw/path/file.md|Name]]"
covered=""
if covered_raw=$(
  obsidian vault="$OBS_VAULT" files folder="wiki/sources" < /dev/null 2>/dev/null \
    | grep '^wiki/sources/src-' \
    | while IFS= read -r src_path; do
        obsidian vault="$OBS_VAULT" property:read name=sources path="$src_path" < /dev/null 2>/dev/null || true
      done \
    | grep -o 'raw/[^]|"]*' \
    | sed 's/\.md$//' \
    | sort -u
); then
  covered="$covered_raw"
else
  echo "Warning: could not build coverage set from sources; assuming all unprocessed" >&2
  covered=""
fi

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
