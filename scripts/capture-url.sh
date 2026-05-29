#!/usr/bin/env bash
# Captures a web article into raw/external/ using defuddle (with pandoc fallback).
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/url-safety.sh
. "$SCRIPT_DIR/lib/url-safety.sh"
# shellcheck source=lib/portable-hash.sh
. "$SCRIPT_DIR/lib/portable-hash.sh"

# Usage: capture-url.sh <url> <vault_path>

URL="${1:?Usage: capture-url.sh <url> <vault_path>}"
VAULT="${2:?Usage: capture-url.sh <url> <vault_path>}"
TODAY=$(date +%Y-%m-%d)

# --- URL validation: only https://, no SSRF targets ---
lib_validate_https_url "$URL" || exit 2
lib_resolve_and_validate_ip "$URL" || exit 2

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 not found" >&2
  exit 1
fi

RAW_DIR="${VAULT}/raw/external"
mkdir -p "$RAW_DIR"

# --- Extract content ---

TITLE=""
AUTHOR=""
CONTENT=""

# Portable timeout wrapper (macOS lacks `timeout` by default).
# Usage: maybe_timeout 60 some-cmd args... — if neither timeout nor gtimeout is
# available, falls through to running the command without any limit.
maybe_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$@"
  else
    shift  # drop the seconds arg
    "$@"
  fi
}

# Primary: defuddle (best signal-to-noise on blogs/articles)
if command -v defuddle &>/dev/null; then
  JSON=$(maybe_timeout 60 defuddle parse "$URL" --json 2>/dev/null) || JSON=""
  if [[ -n "$JSON" ]]; then
    TITLE=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
    AUTHOR=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author',''))" 2>/dev/null || echo "")
    CONTENT=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")
  fi
fi

# Fallback A: trafilatura (replaces pandoc — cleaner output, local-only)
if [[ -z "$CONTENT" ]] || [[ ${#CONTENT} -lt 500 ]]; then
  if command -v trafilatura >/dev/null 2>&1; then
    TRAF_OUT=$(maybe_timeout 60 trafilatura -u "$URL" \
      --output-format markdown \
      --with-metadata \
      --no-tables \
      --precision 2>/dev/null || echo "")
    if [[ ${#TRAF_OUT} -gt ${#CONTENT} ]]; then
      CONTENT="$TRAF_OUT"
      [[ -z "$TITLE" ]] && TITLE=$(echo "$CONTENT" | grep -m1 '^# ' | sed 's/^# //' || echo "")
    fi
  fi
fi

# Fallback B: r.jina.ai cloud (opt-in only via WIKI_ALLOW_CLOUD=1)
if [[ ${#CONTENT} -lt 500 && "${WIKI_ALLOW_CLOUD:-0}" == "1" ]]; then
  # Strip query string and fragment before sending to cloud (privacy)
  local_jina_url="${URL%%\?*}"
  local_jina_url="${local_jina_url%%#*}"
  [[ "$local_jina_url" != "$URL" ]] && echo "warn: query string stripped before cloud capture (privacy)" >&2
  CLOUD_OUT=$(curl -sSL --max-time 30 "https://r.jina.ai/$local_jina_url" 2>/dev/null || echo "")
  if [[ ${#CLOUD_OUT} -gt ${#CONTENT} ]]; then
    CONTENT="$CLOUD_OUT"
    [[ -z "$TITLE" ]] && TITLE=$(echo "$CONTENT" | grep -m1 '^# ' | sed 's/^# //' || echo "")
  fi
fi

# Hard-fail only if ALL three extractors failed
if [[ -z "$CONTENT" ]]; then
  echo "ERROR: extraction failed (defuddle / trafilatura / r.jina.ai). Use capture-text.sh for manual content." >&2
  echo "Install: 'npm i -g defuddle-cli' AND 'uv tool install trafilatura'" >&2
  exit 3
fi

# Cap content at 10MB to prevent unbounded memory usage
CONTENT=$(printf '%s' "$CONTENT" | head -c $((10*1024*1024)))

# Fallback title from URL if empty
if [[ -z "$TITLE" ]]; then
  TITLE=$(echo "$URL" | sed 's|https\?://||;s|/|-|g;s|[?#].*||')
fi

# --- Generate slug ---

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | sed 's/  */ /g' | sed 's/ /-/g' | head -c 80)

# Avoid empty slug
if [[ -z "$SLUG" ]]; then
  SLUG="capture-$(date +%s)"
fi

OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"

# Avoid overwriting existing files
if [[ -f "$OUTPUT" ]]; then
  SLUG="${SLUG}-$(date +%s)"
  OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"
fi

# --- Write file ---

# Content hash for source-drift detection (parity with capture-text.sh, which
# embeds sha256 so verify-source-drift.sh can detect upstream changes).
SHA=$(printf '%s' "$CONTENT" | lib_sha256_stdin)

{
  echo "---"
  echo "title: \"$(lib_yaml_escape "$TITLE")\""
  echo "source_type: article"
  echo "source_url: \"${URL}\""
  echo "captured: ${TODAY}"
  echo "sha256: ${SHA}"
  if [[ -n "$AUTHOR" ]]; then
    echo "author: \"$(lib_yaml_escape "$AUTHOR")\""
  fi
  echo "---"
  echo ""
  echo "$CONTENT"
} > "$OUTPUT"

echo "$OUTPUT"
