#!/usr/bin/env bash
# Usage: capture-youtube.sh <youtube-url> <vault_path>
# Captures a YouTube video transcript into raw/external/.
set -Eeuo pipefail
shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/check-deps.sh
source "$SCRIPT_DIR/lib/check-deps.sh"

# Escape string for safe YAML double-quoted value
yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash
  s="${s//\"/\\\"}"    # double quote
  echo "$s"
}

URL="${1:?Usage: capture-youtube.sh <youtube-url> <vault_path>}"
VAULT="${2:?Usage: capture-youtube.sh <youtube-url> <vault_path>}"
TODAY=$(date +%Y-%m-%d)

lib_check_deps yt-dlp || { echo "Install with: brew install yt-dlp" >&2; exit 1; }

RAW_DIR="${VAULT}/raw/external"
mkdir -p "$RAW_DIR"

# --- Extract video ID ---

VIDEO_ID=""
if [[ "$URL" =~ v=([a-zA-Z0-9_-]{11}) ]]; then
  VIDEO_ID="${BASH_REMATCH[1]}"
elif [[ "$URL" =~ youtu\.be/([a-zA-Z0-9_-]{11}) ]]; then
  VIDEO_ID="${BASH_REMATCH[1]}"
elif [[ "$URL" =~ /shorts/([a-zA-Z0-9_-]{11}) ]]; then
  VIDEO_ID="${BASH_REMATCH[1]}"
fi

if [[ -z "$VIDEO_ID" ]]; then
  echo "Error: could not extract video ID from URL: $URL" >&2
  exit 1
fi

# --- Get video title ---

TITLE=$(yt-dlp --get-title "$URL" 2>/dev/null || echo "youtube-${VIDEO_ID}")

# --- Generate slug ---

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | sed 's/  */ /g' | sed 's/ /-/g' | head -c 80)

if [[ -z "$SLUG" ]]; then
  SLUG="youtube-${VIDEO_ID}"
fi

# --- Download subtitles ---

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

yt-dlp \
  --write-auto-sub \
  --sub-lang en \
  --skip-download \
  --write-subs \
  -o "${TEMP_DIR}/%(id)s" \
  "$URL" 2>/dev/null || true

# Find the subtitle file (.vtt or .srt)
SUB_FILE=""
for ext in vtt srt; do
  CANDIDATE=$(find "$TEMP_DIR" -name "*.${ext}" -type f | head -1)
  if [[ -n "$CANDIDATE" ]]; then
    SUB_FILE="$CANDIDATE"
    break
  fi
done

TRANSCRIPT=""
if [[ -n "$SUB_FILE" ]]; then
  # Strip timestamps and formatting from VTT/SRT, deduplicate lines
  TRANSCRIPT=$(sed '/^$/d; /^[0-9]/d; /^WEBVTT/d; /^Kind:/d; /^Language:/d; /^NOTE/d; /-->/d; s/<[^>]*>//g' "$SUB_FILE" \
    | awk '!seen[$0]++' \
    | sed '/^$/d' \
    | tr '\n' ' ' \
    | sed 's/  */ /g' \
    | fold -s -w 80)
fi

if [[ -z "$TRANSCRIPT" ]]; then
  TRANSCRIPT="*(No English subtitles available for this video)*"
fi

# --- Write file ---

OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"

if [[ -f "$OUTPUT" ]]; then
  SLUG="${SLUG}-$(date +%s)"
  OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"
fi

{
  echo "---"
  echo "title: \"$(yaml_escape "$TITLE")\""
  echo "source_type: video"
  echo "source_url: \"${URL}\""
  echo "video_id: ${VIDEO_ID}"
  echo "captured: ${TODAY}"
  echo "---"
  echo ""
  echo "## Transcript"
  echo ""
  echo "$TRANSCRIPT"
} > "$OUTPUT"

echo "$OUTPUT"
