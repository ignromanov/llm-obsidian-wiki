#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/portable-hash.sh
. "$SCRIPT_DIR/lib/portable-hash.sh"
# shellcheck source=lib/url-safety.sh
. "$SCRIPT_DIR/lib/url-safety.sh"

VAULT_PATH=""; SLUG=""; INPUT=""; INPUT_FILE=""; ORIGIN="text"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --input-file) INPUT_FILE="$2"; shift 2 ;;
    --origin) ORIGIN="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" && -n "$SLUG" ]] || {
  echo "Usage: $0 --vault <p> --slug <s> [--input-file <f>] [--origin <text|clipboard|session>]" >&2
  echo "       (reads from stdin if --input-file omitted)" >&2
  exit 2
}

# Validate slug: must be lowercase alphanumeric + hyphens only
[[ "$SLUG" =~ ^[a-z0-9-]+$ ]] || { echo "slug must match ^[a-z0-9-]+\$: $SLUG" >&2; exit 2; }

case "$ORIGIN" in
  text|clipboard|session) ;;
  *) echo "origin must be: text|clipboard|session" >&2; exit 2 ;;
esac

if [[ -n "$INPUT_FILE" ]]; then
  [[ -f "$INPUT_FILE" ]] || { echo "input file not found" >&2; exit 1; }
  INPUT=$(cat "$INPUT_FILE")
else
  INPUT=$(cat)
fi

[[ -n "$INPUT" ]] || { echo "empty input" >&2; exit 1; }

mkdir -p "$VAULT_PATH/raw/text" "$VAULT_PATH/wiki/sources"

RAW="$VAULT_PATH/raw/text/${SLUG}.md"
SUMMARY="$VAULT_PATH/wiki/sources/${SLUG}.md"

# Hash the input
SHA=$(printf '%s' "$INPUT" | lib_sha256_stdin)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
WORDS=$(echo "$INPUT" | wc -w | tr -d ' ')
QUALITY="high"
[[ "$WORDS" -lt 50 ]] && QUALITY="low"

SAFE_SLUG="$(lib_yaml_escape "$SLUG")"
SAFE_ORIGIN="$(lib_yaml_escape "$ORIGIN")"

cat > "$RAW" <<HEADER
---
type: source
source_type: $SAFE_ORIGIN
slug: $SAFE_SLUG
captured_at: $NOW
captured_by: wiki-scribe
sha256: $SHA
quality: $QUALITY
---

$INPUT
HEADER
chmod 600 "$RAW"

cat > "$SUMMARY" <<HEADER
---
type: source-summary
source_type: $SAFE_ORIGIN
slug: $SAFE_SLUG
captured_at: $NOW
captured_by: wiki-scribe
sha256: $SHA
raw_path: raw/text/${SAFE_SLUG}.md
quality: $QUALITY
tier: 4
key_claims: []
---

# $SAFE_SLUG

Captured from $SAFE_ORIGIN ($WORDS words). See [[${SAFE_SLUG}]] in raw/ for full content.
HEADER
chmod 600 "$SUMMARY"

echo "Captured: $SLUG → raw/text/${SLUG}.md + wiki/sources/${SLUG}.md (sha=$SHA)"
