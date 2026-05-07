#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/portable-hash.sh
. "$SCRIPT_DIR/lib/portable-hash.sh"
# shellcheck source=lib/check-deps.sh
. "$SCRIPT_DIR/lib/check-deps.sh"

lib_check_deps pandoc || exit 1

VAULT_PATH=""; SRC=""; SLUG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    --source) SRC="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" && -n "$SRC" ]] || {
  echo "Usage: $0 --vault <p> --source <pdf-path-or-url> [--slug <slug>]" >&2
  exit 2
}

# Resolve PDF locally
PDF_LOCAL=""
if [[ "$SRC" =~ ^https?:// ]]; then
  PDF_LOCAL=$(mktemp -t pdf-XXXXXX.pdf)
  curl -sSL --max-time 60 -o "$PDF_LOCAL" "$SRC" || {
    echo "download failed" >&2; exit 1
  }
else
  [[ -f "$SRC" ]] || { echo "PDF not found: $SRC" >&2; exit 1; }
  PDF_LOCAL="$SRC"
fi

# Slug
[[ -n "$SLUG" ]] || SLUG=$(basename "$SRC" .pdf | tr '[:upper:] /' '[:lower:]--' | tr -cd 'a-z0-9-')

mkdir -p "$VAULT_PATH/raw/pdf" "$VAULT_PATH/wiki/sources"

RAW="$VAULT_PATH/raw/pdf/${SLUG}.md"
SUMMARY="$VAULT_PATH/wiki/sources/${SLUG}.md"

# Convert via pandoc
CONTENT=$(pandoc -f pdf -t markdown "$PDF_LOCAL" 2>/dev/null || echo "")
[[ -n "$CONTENT" ]] || { echo "pandoc conversion failed" >&2; exit 1; }

SHA=$(lib_sha256 "$PDF_LOCAL")
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$RAW" <<HEADER
---
type: source
source_type: pdf
slug: $SLUG
captured_at: $NOW
captured_by: wiki-scribe
sha256: $SHA
original_url: $SRC
quality: high
---

$CONTENT
HEADER
chmod 600 "$RAW"

WORDS=$(echo "$CONTENT" | wc -w | tr -d ' ')
QUALITY="high"
[[ "$WORDS" -lt 500 ]] && QUALITY="low"

cat > "$SUMMARY" <<HEADER
---
type: source-summary
source_type: pdf
slug: $SLUG
captured_at: $NOW
captured_by: wiki-scribe
sha256: $SHA
raw_path: raw/pdf/${SLUG}.md
original_url: $SRC
quality: $QUALITY
tier: 4
key_claims: []
---

# $SLUG

Captured from PDF. See [[${SLUG}]] in raw/ for full content.

## Top quotes
_(to be extracted by next research/audit run)_
HEADER
chmod 600 "$SUMMARY"

# Cleanup downloaded
[[ "$SRC" =~ ^https?:// ]] && rm -f "$PDF_LOCAL"

echo "Captured: $SLUG → raw/pdf/${SLUG}.md + wiki/sources/${SLUG}.md (sha=$SHA, quality=$QUALITY)"
