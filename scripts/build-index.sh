#!/usr/bin/env bash
# Regenerates the vault's index.md from domain hubs (_hub.md files).
# Content BELOW the sentinel marker is machine-generated; everything above is
# preserved verbatim. If the marker is absent on first run, the existing file
# is backed up to index.md.bak (only if .bak does not already exist) and the
# sentinel + generated content is appended below the preserved prose.
#
# Usage: build-index.sh --vault <path>
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
umask 077

VAULT_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$VAULT_PATH" ]] || { echo "Usage: $0 --vault <path>" >&2; exit 2; }
[[ -d "$VAULT_PATH" ]] || { echo "vault not found: $VAULT_PATH" >&2; exit 1; }

CONFIG="$VAULT_PATH/wiki.config.md"
[[ -f "$CONFIG" ]] || { echo "wiki.config.md not found at $CONFIG" >&2; exit 1; }

# Resolve index file from config; fall back to index.md
INDEX_FILE=$(grep -E '^index_file:' "$CONFIG" 2>/dev/null | sed 's/^index_file: *//' | tr -d '"' || echo "")
INDEX="$VAULT_PATH/${INDEX_FILE:-index.md}"

SENTINEL="<!-- AUTO-GENERATED INDEX — do not edit below this line -->"

# Scan wiki/*/_hub.md, collect (path, member-count), sort by path
HUB_LINES=""
while IFS= read -r hub; do
  rel="${hub#"$VAULT_PATH"/}"
  # Hub directory basename is used to derive the wikilink (the hub slug itself)
  dir=$(dirname "$rel")           # e.g. wiki/concepts
  slug=$(basename "$dir")         # e.g. concepts
  hub_slug="${dir}/_hub"          # wikilink target: wiki/concepts/_hub
  members=$(grep -oE '\[\[[^]]+\]\]' "$hub" | wc -l | tr -d ' ')
  HUB_LINES="${HUB_LINES}${rel}|${slug}|${hub_slug}|${members}"$'\n'
done < <(find "$VAULT_PATH/wiki" -name "_hub.md" -type f | sort)

# Build the generated section
GENERATED=""
GENERATED+="## Domain hubs"$'\n'$'\n'
while IFS='|' read -r rel slug hub_slug members; do
  [[ -z "$rel" ]] && continue
  GENERATED+="- [[${hub_slug}]] (${members} members)"$'\n'
done <<< "$HUB_LINES"

BLOCK="${SENTINEL}"$'\n'"${GENERATED}"

# Handle index.md: preserve prose above sentinel, regenerate below
if [[ -f "$INDEX" ]]; then
  if grep -qF "$SENTINEL" "$INDEX"; then
    # Sentinel present: replace everything from sentinel onward
    # Extract content before the sentinel
    BEFORE=$(python3 - "$INDEX" "$SENTINEL" <<'PY'
import sys
path, marker = sys.argv[1], sys.argv[2]
with open(path) as f:
    text = f.read()
idx = text.find(marker)
if idx == -1:
    sys.exit(1)
sys.stdout.write(text[:idx])
PY
)
    # Write: prose before + new block.
    # BEFORE loses trailing newlines via command substitution; add separator explicitly.
    printf '%s\n\n%s\n' "$BEFORE" "$BLOCK" > "$INDEX"
  else
    # No sentinel: back up original (only if no .bak yet), then append sentinel + content
    BAK="${INDEX}.bak"
    if [[ ! -f "$BAK" ]]; then
      cp "$INDEX" "$BAK"
    fi
    # Append sentinel + generated section below existing content
    existing=$(cat "$INDEX")
    printf '%s\n\n%s\n' "$existing" "$BLOCK" > "$INDEX"
  fi
else
  # No index file: create from scratch
  printf '%s\n' "$BLOCK" > "$INDEX"
fi

HUB_COUNT=$(find "$VAULT_PATH/wiki" -name "_hub.md" -type f | wc -l | tr -d ' ')
echo "index.md regenerated from ${HUB_COUNT} hubs"
