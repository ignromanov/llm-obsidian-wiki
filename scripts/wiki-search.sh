#!/usr/bin/env bash
# Usage: wiki-search.sh <vault_path> "<query>" [limit]
# Combined search + TLDR triage in one call.
# Returns search results with inline TLDRs and related tags for broadening.
# Format: [section]\nstructured data — designed for LLM agent consumption.
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/read-yaml-key.sh
source "$SCRIPT_DIR/lib/read-yaml-key.sh"

usage() {
  cat >&2 <<'EOF'
Usage: wiki-search.sh <vault_path> "<query>" [limit]
       wiki-search.sh --vault <path> --query "<text>" [--limit <n>]
Combined search + TLDR triage. Flags and positional args are interchangeable.
EOF
}

# Accept both flag form (--vault/--query/--limit) and the original positional
# form (<vault> <query> [limit]). SKILL docs use flags; existing callers use
# positional — support both so neither silently fails (#4).
VAULT_PATH=""; QUERY=""; LIMIT=20
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT_PATH="${2:?--vault needs a value}"; shift 2 ;;
    --query) QUERY="${2:?--query needs a value}"; shift 2 ;;
    --limit) LIMIT="${2:?--limit needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [[ $# -gt 0 ]]; do POSITIONAL+=("$1"); shift; done; break ;;
    -*) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

[[ -z "$VAULT_PATH" && ${#POSITIONAL[@]} -ge 1 ]] && VAULT_PATH="${POSITIONAL[0]}"
[[ -z "$QUERY"      && ${#POSITIONAL[@]} -ge 2 ]] && QUERY="${POSITIONAL[1]}"
[[ ${#POSITIONAL[@]} -ge 3 ]] && LIMIT="${POSITIONAL[2]}"

[[ -n "$VAULT_PATH" && -n "$QUERY" ]] || { usage; exit 2; }
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "limit must be a positive integer: $LIMIT" >&2; exit 2; }

OBS_VAULT=$(lib_read_yaml_key "${VAULT_PATH}/wiki.config.md" "vault_name")
if [[ -z "$OBS_VAULT" ]]; then
  echo "Error: vault_name not found in wiki.config.md" >&2
  exit 1
fi

# --- Search results with TLDRs ---
echo "[results]"
count=0
all_tags=""

while IFS= read -r filepath; do
  [[ -z "$filepath" ]] && continue
  # Skip structural files
  case "$filepath" in
    */_hub.md|index.md|log.md) continue ;;
  esac

  slug=$(basename "$filepath" .md)
  title=$(obsidian vault="$OBS_VAULT" property:read name=title path="$filepath" < /dev/null 2>/dev/null || echo "$slug")
  type=$(obsidian vault="$OBS_VAULT" property:read name=type path="$filepath" < /dev/null 2>/dev/null || echo "?")
  tldr=$(obsidian vault="$OBS_VAULT" property:read name=tldr path="$filepath" < /dev/null 2>/dev/null || echo "")

  # Collect tags for broadening
  page_tags=$(obsidian vault="$OBS_VAULT" property:read name=tags path="$filepath" < /dev/null 2>/dev/null || echo "")
  if [[ -n "$page_tags" ]]; then
    all_tags+="$page_tags"$'\n'
  fi

  # Truncate TLDR for triage
  [[ ${#tldr} -gt 150 ]] && tldr="${tldr:0:150}..."

  echo "$filepath | $type | $title | $tldr"
  ((count++)) || true
done < <(obsidian vault="$OBS_VAULT" search query="$QUERY" path=wiki limit="$LIMIT" < /dev/null 2>/dev/null)

echo "results_total=$count"

# --- Related tags with vault-wide counts (for broadening) ---
if [[ -n "$all_tags" ]]; then
  echo ""
  echo "[related_tags]"

  # Get vault-wide tag counts
  vault_tags=$(obsidian vault="$OBS_VAULT" tags sort=count counts < /dev/null 2>/dev/null)

  # Deduplicate tags from results, look up vault counts
  echo "$all_tags" | sort -u | while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    tag_count=$(echo "$vault_tags" | awk -v t="#$tag" '$1 == t {print $2}')
    [[ -n "$tag_count" ]] && echo "#$tag	$tag_count"
  done | sort -t$'\t' -k2 -nr
fi
