#!/usr/bin/env bash
# Usage: init-vault.sh <vault_path> <config_file>
# Reads wiki.config.md and creates the full Obsidian vault directory structure.
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/canonical-path.sh
source "$SCRIPT_DIR/lib/canonical-path.sh"
# shellcheck source=./lib/check-deps.sh
source "$SCRIPT_DIR/lib/check-deps.sh"

lib_check_deps git || exit 1

VAULT="${1:?Usage: init-vault.sh <vault_path> <config_file>}"
CONFIG="${2:?Usage: init-vault.sh <vault_path> <config_file>}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

# --- Parse config frontmatter ---

# Extract YAML frontmatter between --- delimiters
FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$CONFIG" | sed '1d;$d')

# Extract page_types (YAML list under page_types:)
PAGE_TYPES=()
IN_PAGE_TYPES=false
while IFS= read -r line; do
  if [[ "$line" =~ ^page_types: ]]; then
    IN_PAGE_TYPES=true
    continue
  fi
  if $IN_PAGE_TYPES; then
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
      PAGE_TYPES+=("${BASH_REMATCH[1]}")
    else
      IN_PAGE_TYPES=false
    fi
  fi
done <<< "$FRONTMATTER"

# Extract raw_dirs (YAML list under raw_dirs:)
RAW_DIRS=()
IN_RAW_DIRS=false
while IFS= read -r line; do
  if [[ "$line" =~ ^raw_dirs: ]]; then
    IN_RAW_DIRS=true
    continue
  fi
  if $IN_RAW_DIRS; then
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
      RAW_DIRS+=("${BASH_REMATCH[1]}")
    else
      IN_RAW_DIRS=false
    fi
  fi
done <<< "$FRONTMATTER"

# Map page type to directory name (singular→plural, etc.)
type_to_dir() {
  case "$1" in
    concept) echo "concepts" ;;
    entity) echo "entities" ;;
    decision) echo "decisions" ;;
    org) echo "orgs" ;;
    comparison) echo "comparisons" ;;
    source-summary) echo "sources" ;;
    open-question) echo "open-questions" ;;
    *) echo "$1" ;;
  esac
}

# Defaults if not specified
if [[ ${#PAGE_TYPES[@]} -eq 0 ]]; then
  PAGE_TYPES=(concepts entities sources decisions)
  echo "No page_types found in config, using defaults: ${PAGE_TYPES[*]}"
fi

if [[ ${#RAW_DIRS[@]} -eq 0 ]]; then
  RAW_DIRS=(internal external)
  echo "No raw_dirs found in config, using defaults: ${RAW_DIRS[*]}"
fi

CREATED=()

# --- Create directory structure ---

# raw/ directories
for dir in "${RAW_DIRS[@]}"; do
  target="${VAULT}/raw/${dir}"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    CREATED+=("raw/${dir}/")
  fi
done

# wiki/ directories
for ptype in "${PAGE_TYPES[@]}"; do
  dir_name=$(type_to_dir "$ptype")
  target="${VAULT}/wiki/${dir_name}"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    CREATED+=("wiki/${ptype}/")
  fi
done

# v0.4.0 fixed dirs (drafts / contradictions / logs)
for fixed_dir in _drafts contradictions _logs; do
  target="${VAULT}/wiki/${fixed_dir}"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    touch "$target/.gitkeep"
    CREATED+=("wiki/${fixed_dir}/")
  fi
done

# v0.4.0 hot.md (rolling session cache) — seed from template if available
HOT_TEMPLATE="${SCRIPT_DIR}/templates/_hot.md"
HOT_TARGET="${VAULT}/wiki/hot.md"
if [[ -f "$HOT_TEMPLATE" && ! -f "$HOT_TARGET" ]]; then
  NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sed "s|{{NOW_ISO8601}}|$NOW_ISO|g" "$HOT_TEMPLATE" > "$HOT_TARGET"
  chmod 600 "$HOT_TARGET"
  CREATED+=("wiki/hot.md")
fi

# assets/
if [[ ! -d "${VAULT}/assets" ]]; then
  mkdir -p "${VAULT}/assets"
  CREATED+=("assets/")
fi

# --- Obsidian config ---

OBSIDIAN_DIR="${VAULT}/.obsidian"
if [[ ! -d "$OBSIDIAN_DIR" ]]; then
  mkdir -p "$OBSIDIAN_DIR"
  CREATED+=(".obsidian/")
fi

# app.json — minimal Obsidian settings
if [[ ! -f "${OBSIDIAN_DIR}/app.json" ]]; then
  cat > "${OBSIDIAN_DIR}/app.json" << 'APPJSON'
{
  "strictLineBreaks": false,
  "showFrontmatter": true,
  "livePreview": true,
  "readableLineLength": true
}
APPJSON
  CREATED+=(".obsidian/app.json")
fi

# appearance.json — dark mode default
if [[ ! -f "${OBSIDIAN_DIR}/appearance.json" ]]; then
  cat > "${OBSIDIAN_DIR}/appearance.json" << 'APPEARJSON'
{
  "theme": "obsidian"
}
APPEARJSON
  CREATED+=(".obsidian/appearance.json")
fi

# --- .gitignore ---

GITIGNORE="${VAULT}/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" << 'GITIGNORE'
# Obsidian workspace (user-specific, changes constantly)
.obsidian/workspace*.json
.obsidian/graph.json
.obsidian/backlink.json

# OS
.DS_Store
Thumbs.db

# Obsidian trash
.trash/
GITIGNORE
  CREATED+=(".gitignore")
fi

# --- Git init ---

if [[ ! -d "${VAULT}/.git" ]]; then
  git -C "$VAULT" init -q
  CREATED+=(".git/ (initialized)")
fi

# --- Copy config to vault root ---

VAULT_CONFIG="${VAULT}/wiki.config.md"
if [[ ! -f "$VAULT_CONFIG" ]] && [[ "$(lib_canonical_path "$CONFIG")" != "$(lib_canonical_path "$VAULT_CONFIG")" ]]; then
  cp "$CONFIG" "$VAULT_CONFIG"
  CREATED+=("wiki.config.md")
fi

# --- Summary ---

echo "Vault initialized at: ${VAULT}"
echo ""
echo "Created ${#CREATED[@]} items:"
for item in "${CREATED[@]}"; do
  echo "  + ${item}"
done
echo ""
echo "Page types: ${PAGE_TYPES[*]}"
echo "Raw dirs: ${RAW_DIRS[*]}"
