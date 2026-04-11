#!/bin/bash
set -euo pipefail

# Usage: capture-prs.sh <repo> <vault_path> [since_date]
# Example: capture-prs.sh ignromanov/voidpay /path/to/wiki 2026-04-08
# If no since_date, captures last 7 days

REPO="${1:?Usage: capture-prs.sh <owner/repo> <vault_path> [since_date]}"
VAULT="${2:?Usage: capture-prs.sh <owner/repo> <vault_path> [since_date]}"
SINCE="${3:-$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)}"
TODAY=$(date +%Y-%m-%d)
RAW_DIR="${VAULT}/raw/inbox"
mkdir -p "$RAW_DIR"

# --- Fetch merged PRs ---

PRS=$(gh pr list --repo "$REPO" --state merged --search "merged:>$SINCE" --json number,title,body,mergedAt,author,files --limit 50 2>/dev/null || echo "[]")

COUNT=$(echo "$PRS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [[ "$COUNT" == "0" ]]; then
  echo "No merged PRs found in $REPO since $SINCE"
  exit 0
fi

echo "Found $COUNT merged PRs in $REPO since $SINCE"

# --- Process each PR ---

CREATED=0

echo "$PRS" | python3 -c "
import json, sys, re, os

prs = json.load(sys.stdin)
vault = '$VAULT'
raw_dir = '$RAW_DIR'
today = '$TODAY'
repo = '$REPO'

for pr in prs:
    number = pr['number']
    title = pr.get('title', 'Untitled')
    body = pr.get('body', '') or ''
    merged = pr.get('mergedAt', '')[:10]
    author = pr.get('author', {}).get('login', 'unknown')
    files = pr.get('files', [])

    # Generate slug
    slug = re.sub(r'[^a-z0-9 -]', '', title.lower())
    slug = re.sub(r'\s+', '-', slug.strip())[:60]
    filename = f'pr-{number}-{slug}.md'
    filepath = os.path.join(raw_dir, filename)

    if os.path.exists(filepath):
        print(f'SKIP: {filename} (already exists)')
        continue

    # File list
    file_list = ''
    if files:
        for f in files:
            path = f.get('path', '') if isinstance(f, dict) else str(f)
            file_list += f'- \`{path}\`\n'
    else:
        file_list = '*(file list not available)*\n'

    content = f'''---
title: \"PR #{number}: {title}\"
source_type: pull-request
source_url: https://github.com/{repo}/pull/{number}
captured: {today}
merged: {merged}
author: {author}
files_changed: {len(files) if files else 'unknown'}
---

# PR #{number}: {title}

**Merged**: {merged} by @{author}

## Description

{body if body else '*(no description)*'}

## Files Changed

{file_list}
'''

    with open(filepath, 'w') as f:
        f.write(content)
    print(f'NEW: {filename}')
" 2>&1

echo ""
echo "Capture complete. Files saved to $RAW_DIR"
