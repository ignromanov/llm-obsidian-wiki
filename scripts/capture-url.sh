#!/usr/bin/env bash
# Captures a web article into raw/external/ using defuddle (with pandoc fallback).
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

# Escape string for safe YAML double-quoted value
yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash
  s="${s//\"/\\\"}"    # double quote
  echo "$s"
}

# Usage: capture-url.sh <url> <vault_path>

URL="${1:?Usage: capture-url.sh <url> <vault_path>}"
VAULT="${2:?Usage: capture-url.sh <url> <vault_path>}"
TODAY=$(date +%Y-%m-%d)

# --- URL validation: only https://, no SSRF targets ---
validate_https_url() {
  local url="$1"
  [[ "$url" =~ ^https://[^[:space:]]+$ ]] || { echo "ERROR: only https:// URLs allowed" >&2; exit 2; }
  # Extract hostname
  local host="${url#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  # Reject localhost/RFC1918 by name or literal IP prefix
  case "$host" in
    localhost|127.*|0.0.0.0|::1) echo "ERROR: loopback blocked" >&2; exit 2 ;;
    169.254.*) echo "ERROR: link-local blocked" >&2; exit 2 ;;
    10.*|192.168.*) echo "ERROR: RFC1918 blocked" >&2; exit 2 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "ERROR: RFC1918 blocked" >&2; exit 2 ;;
  esac
}

# DNS-resolve hostname and validate the resulting IP (DNS rebinding protection)
resolve_and_validate_ip() {
  local url="$1"
  local host="${url#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  local ip=""
  if command -v getent >/dev/null 2>&1; then
    ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
  elif command -v python3 >/dev/null 2>&1; then
    ip=$(python3 -c "import socket,sys; print(socket.gethostbyname(sys.argv[1]))" "$host" 2>/dev/null) || true
  else
    echo "WARN: no DNS resolver available, skipping IP validation" >&2
    return 0
  fi
  [[ -n "$ip" ]] || { echo "ERROR: DNS resolution failed for $host" >&2; exit 2; }
  case "$ip" in
    127.*|0.0.0.0|::1) echo "ERROR: resolved to loopback: $ip" >&2; exit 2 ;;
    169.254.*) echo "ERROR: resolved to link-local: $ip" >&2; exit 2 ;;
    10.*|192.168.*) echo "ERROR: resolved to RFC1918: $ip" >&2; exit 2 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "ERROR: resolved to RFC1918: $ip" >&2; exit 2 ;;
  esac
}

validate_https_url "$URL"
resolve_and_validate_ip "$URL"

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

if command -v defuddle &>/dev/null; then
  JSON=$(timeout 60 defuddle parse "$URL" --json) || { echo "ERROR: defuddle failed or timed out" >&2; exit 3; }
  TITLE=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
  AUTHOR=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author',''))" 2>/dev/null || echo "")
  CONTENT=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")
else
  echo "defuddle not found, falling back to curl + pandoc" >&2
  if ! command -v pandoc &>/dev/null; then
    echo "Error: neither defuddle nor pandoc found" >&2
    exit 1
  fi
  CONTENT=$(curl --fail --max-time 60 --max-filesize 10M --proto '=https' --proto-default https -sSL "$URL" | pandoc -f html -t markdown)
  # Extract title from first H1 if present
  TITLE=$(echo "$CONTENT" | grep -m1 '^# ' | sed 's/^# //' || echo "")
fi

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

{
  echo "---"
  echo "title: \"$(yaml_escape "$TITLE")\""
  echo "source_type: article"
  echo "source_url: \"${URL}\""
  echo "captured: ${TODAY}"
  if [[ -n "$AUTHOR" ]]; then
    echo "author: \"$(yaml_escape "$AUTHOR")\""
  fi
  echo "---"
  echo ""
  echo "$CONTENT"
} > "$OUTPUT"

echo "$OUTPUT"
