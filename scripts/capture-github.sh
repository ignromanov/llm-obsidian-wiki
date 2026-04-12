#!/usr/bin/env bash
# Captures a GitHub issue, PR, discussion, or repo README into raw/external/.
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

# Usage: capture-github.sh <github-url> <vault_path>

URL="${1:?Usage: capture-github.sh <github-url> <vault_path>}"
VAULT="${2:?Usage: capture-github.sh <github-url> <vault_path>}"
TODAY=$(date +%Y-%m-%d)

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install with: brew install gh" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 not found" >&2
  exit 1
fi

RAW_DIR="${VAULT}/raw/external"
mkdir -p "$RAW_DIR"

# --- Parse GitHub URL ---

# Strip trailing slashes and .git
CLEAN_URL=$(echo "$URL" | sed 's|/$||; s|\.git$||')

# Extract owner/repo and type
# Patterns: github.com/owner/repo[/issues|pulls|pull|discussions/number]
OWNER_REPO=""
RESOURCE_TYPE=""
NUMBER=""

if [[ "$CLEAN_URL" =~ github\.com/([^/]+/[^/]+)/issues/([0-9]+) ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}"
  RESOURCE_TYPE="issue"
  NUMBER="${BASH_REMATCH[2]}"
elif [[ "$CLEAN_URL" =~ github\.com/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}"
  RESOURCE_TYPE="pr"
  NUMBER="${BASH_REMATCH[2]}"
elif [[ "$CLEAN_URL" =~ github\.com/([^/]+/[^/]+)/discussions/([0-9]+) ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}"
  RESOURCE_TYPE="discussion"
  NUMBER="${BASH_REMATCH[2]}"
elif [[ "$CLEAN_URL" =~ github\.com/([^/]+/[^/]+)$ ]]; then
  OWNER_REPO="${BASH_REMATCH[1]}"
  RESOURCE_TYPE="repo"
else
  echo "Error: could not parse GitHub URL: $URL" >&2
  echo "Supported: issues, PRs, discussions, repo root" >&2
  exit 1
fi

# Validate owner/repo to prevent GraphQL injection and shell substitution
[[ "$OWNER_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || {
  echo "ERROR: invalid owner/repo format: $OWNER_REPO" >&2
  exit 2
}
OWNER="${OWNER_REPO%%/*}"
REPO_NAME="${OWNER_REPO##*/}"

# --- Fetch content based on type ---

TITLE=""
BODY=""
SOURCE_TYPE=""
SLUG=""

case "$RESOURCE_TYPE" in
  issue)
    SOURCE_TYPE="github-issue"
    JSON=$(gh issue view "$NUMBER" --repo "$OWNER_REPO" --json title,body,comments,author,createdAt)
    TITLE=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
    AUTHOR=$(echo "$JSON" | python3 -c "import sys,json; data=json.load(sys.stdin); print((data.get('author') or {}).get('login', 'unknown'))")
    CREATED=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['createdAt'][:10])")
    ISSUE_BODY=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body','') or '')")
    COMMENTS=$(echo "$JSON" | python3 -c "
import sys,json
data = json.load(sys.stdin)
for c in data.get('comments',[]):
    print(f\"### Comment by {(c.get('author') or {}).get('login', 'unknown')} ({c['createdAt'][:10]})\")
    print()
    print(c.get('body',''))
    print()
")

    BODY=$(printf "%s\n\n## Comments\n\n%s" "$ISSUE_BODY" "$COMMENTS")
    SLUG=$(echo "${OWNER_REPO//\//-}-issue-${NUMBER}" | tr '[:upper:]' '[:lower:]')
    ;;

  pr)
    SOURCE_TYPE="github-pr"
    JSON=$(gh pr view "$NUMBER" --repo "$OWNER_REPO" --json title,body,comments,author,createdAt)
    TITLE=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
    AUTHOR=$(echo "$JSON" | python3 -c "import sys,json; data=json.load(sys.stdin); print((data.get('author') or {}).get('login', 'unknown'))")
    CREATED=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['createdAt'][:10])")
    PR_BODY=$(echo "$JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body','') or '')")
    COMMENTS=$(echo "$JSON" | python3 -c "
import sys,json
data = json.load(sys.stdin)
for c in data.get('comments',[]):
    print(f\"### Comment by {(c.get('author') or {}).get('login', 'unknown')} ({c['createdAt'][:10]})\")
    print()
    print(c.get('body',''))
    print()
")

    BODY=$(printf "%s\n\n## Comments\n\n%s" "$PR_BODY" "$COMMENTS")
    SLUG=$(echo "${OWNER_REPO//\//-}-pr-${NUMBER}" | tr '[:upper:]' '[:lower:]')
    ;;

  discussion)
    SOURCE_TYPE="github-discussion"
    # gh doesn't have native discussion view; use GraphQL API with -F variables (not string interpolation)
    # shellcheck disable=SC2016
    JSON=$(gh api graphql \
      -F owner="$OWNER" \
      -F name="$REPO_NAME" \
      -F num="$NUMBER" \
      -f query='
        query($owner: String!, $name: String!, $num: Int!) {
          repository(owner: $owner, name: $name) {
            discussion(number: $num) {
              title
              body
              author { login }
              createdAt
              comments(first: 50) {
                nodes { body author { login } createdAt }
              }
            }
          }
        }
      ' 2>/dev/null || echo "")

    if [[ -n "$JSON" ]]; then
      TITLE=$(echo "$JSON" | python3 -c "
import sys,json
d = json.load(sys.stdin)
disc = d.get('data',{}).get('repository',{}).get('discussion',{})
print(disc.get('title', 'Discussion #${NUMBER}'))
" 2>/dev/null || echo "Discussion #${NUMBER}")
      BODY=$(echo "$JSON" | python3 -c "
import sys,json
d = json.load(sys.stdin)
disc = d.get('data',{}).get('repository',{}).get('discussion',{})
print(disc.get('body',''))
comments = disc.get('comments',{}).get('nodes',[])
if comments:
    print('\n## Comments\n')
    for c in comments:
        print(f\"### Comment by {(c.get('author') or {}).get('login', 'unknown')} ({c['createdAt'][:10]})\")
        print()
        print(c.get('body',''))
        print()
" 2>/dev/null || echo "*(Could not fetch discussion body)*")
      AUTHOR=$(echo "$JSON" | python3 -c "
import sys,json
d = json.load(sys.stdin)
disc = d.get('data',{}).get('repository',{}).get('discussion',{})
print(disc.get('author',{}).get('login','unknown'))
" 2>/dev/null || echo "unknown")
      CREATED="$TODAY"
    else
      TITLE="Discussion #${NUMBER}"
      BODY="*(Could not fetch discussion content)*"
      AUTHOR="unknown"
      CREATED="$TODAY"
    fi
    SLUG=$(echo "${OWNER_REPO//\//-}-discussion-${NUMBER}" | tr '[:upper:]' '[:lower:]')
    ;;

  repo)
    SOURCE_TYPE="github-repo"
    # Fetch README; --decode works on both BSD (macOS) and GNU base64
    README_CONTENT=$(gh api "repos/${OWNER_REPO}/readme" --jq .content 2>/dev/null | base64 --decode 2>/dev/null || echo "")

    if [[ -z "$README_CONTENT" ]]; then
      echo "Error: could not fetch README for ${OWNER_REPO}" >&2
      exit 1
    fi

    # Get repo description for title
    TITLE=$(gh api "repos/${OWNER_REPO}" --jq '.full_name + " — " + (.description // "")' 2>/dev/null || echo "$OWNER_REPO")
    AUTHOR=$(echo "$OWNER_REPO" | cut -d'/' -f1)
    CREATED="$TODAY"
    BODY="$README_CONTENT"
    SLUG=$(echo "${OWNER_REPO//\//-}-readme" | tr '[:upper:]' '[:lower:]')
    ;;
esac

# --- Write file ---

OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"

if [[ -f "$OUTPUT" ]]; then
  SLUG="${SLUG}-$(date +%s)"
  OUTPUT="${RAW_DIR}/${TODAY}-${SLUG}.md"
fi

{
  echo "---"
  echo "title: \"$(yaml_escape "$TITLE")\""
  echo "source_type: ${SOURCE_TYPE}"
  echo "source_url: \"${URL}\""
  echo "captured: ${TODAY}"
  if [[ -n "${AUTHOR:-}" ]]; then
    echo "author: \"$(yaml_escape "$AUTHOR")\""
  fi
  if [[ -n "${CREATED:-}" ]]; then
    echo "source_date: ${CREATED}"
  fi
  echo "github_repo: ${OWNER_REPO}"
  if [[ -n "${NUMBER:-}" ]]; then
    echo "github_number: ${NUMBER}"
  fi
  echo "---"
  echo ""
  echo "$BODY"
} > "$OUTPUT"

echo "$OUTPUT"
