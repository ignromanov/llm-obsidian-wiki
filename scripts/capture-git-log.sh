#!/usr/bin/env bash
# Usage: capture-git-log.sh <repo_path> <vault_path> [since_date]
# Example: capture-git-log.sh /path/to/voidpay /path/to/wiki 2026-04-08
set -Eeuo pipefail
[[ ${BASH_VERSINFO[0]:-0} -ge 4 ]] && shopt -s inherit_errexit
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=./lib/check-deps.sh
source "$SCRIPT_DIR/lib/check-deps.sh"

lib_check_deps git || exit 1

REPO_PATH="${1:?Usage: capture-git-log.sh <repo_path> <vault_path> [since_date]}"
VAULT="${2:?Usage: capture-git-log.sh <repo_path> <vault_path> [since_date]}"
# BSD/GNU date portable: keep the good pattern
SINCE="${3:-$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)}"
TODAY=$(date +%Y-%m-%d)
RAW_DIR="${VAULT}/raw/inbox"
mkdir -p "$RAW_DIR"

# --- Get repo name ---
REPO_NAME=$(basename "$REPO_PATH")

# --- Get commits ---
LOG=$(git -C "$REPO_PATH" log --oneline --since="$SINCE" --no-merges 2>/dev/null || echo "")

if [[ -z "$LOG" ]]; then
  echo "No commits found in $REPO_NAME since $SINCE"
  exit 0
fi

COUNT=$(echo "$LOG" | wc -l | tr -d ' ')
echo "Found $COUNT commits in $REPO_NAME since $SINCE"

# --- Get detailed log ---
DETAILED=$(git -C "$REPO_PATH" log --since="$SINCE" --no-merges --format="### %h — %s%n%n**Date**: %ai | **Author**: %an%n" 2>/dev/null || echo "")

# --- Get diffstat ---
FIRST_HASH=$(git -C "$REPO_PATH" log --since="$SINCE" --reverse --format="%H" | head -1)
DIFFSTAT=$(git -C "$REPO_PATH" diff --stat "${FIRST_HASH}^"..HEAD 2>/dev/null || git -C "$REPO_PATH" diff --stat "${FIRST_HASH}"..HEAD 2>/dev/null || echo "*(diffstat unavailable)*")

# --- Write file ---
FILENAME="git-log-${REPO_NAME}-${TODAY}.md"
OUTPUT="${RAW_DIR}/${FILENAME}"

if [[ -f "$OUTPUT" ]]; then
  FILENAME="git-log-${REPO_NAME}-${TODAY}-$(date +%s).md"
  OUTPUT="${RAW_DIR}/${FILENAME}"
fi

cat > "$OUTPUT" <<EOF
---
title: "Git Log: ${REPO_NAME} since ${SINCE}"
source_type: git-log
source_url: file://${REPO_PATH}
captured: ${TODAY}
since: ${SINCE}
commit_count: ${COUNT}
---

# Git Log: ${REPO_NAME}

**Period**: ${SINCE} → ${TODAY} | **Commits**: ${COUNT}

## Commits

${DETAILED}

## Diffstat

\`\`\`
${DIFFSTAT}
\`\`\`
EOF

echo "NEW: ${FILENAME}"
echo "Capture complete. File saved to ${RAW_DIR}/${FILENAME}"
