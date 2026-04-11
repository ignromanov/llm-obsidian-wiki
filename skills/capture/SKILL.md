---
name: capture
version: 0.1.0
description: |
  This skill should be used when the user wants to save a source into the wiki's raw/ directory.
  Triggers: capture URL, save article, clip web page, download PDF, YouTube
  transcript, GitHub issue, tweet thread, clipboard save, sync internal files,
  capture PRs, capture git log, sync code changes,
  or any mention of "capture", "raw", "source", "web clip", "ingest from".
---

# Capture — Collect Raw Sources

Collect external and internal sources into the wiki's `raw/` directory as immutable markdown files with structured frontmatter.

## Setup

Read `wiki.config.md` at the vault root to get:
- `vault_name` → store as `$VAULT` (for `obsidian vault="$VAULT"` commands)
- `plugin_root` → store as `$PLUGIN_ROOT` (for scripts like `$PLUGIN_ROOT/scripts/capture-url.sh`)
- `capture_tools` — list of installed capture tools (defuddle, yt-dlp, pandoc)

Set `RAW_DIR` to the `raw/` directory relative to where `wiki.config.md` lives.

## Source Detection

Auto-detect source type from the input:

| Pattern | Source type | Mode |
|---------|-------------|------|
| `https://*.youtube.com/*`, `https://youtu.be/*` | `video` | YouTube |
| `https://github.com/*/*/issues/*` | `github` | GitHub |
| `https://github.com/*/*/pull/*` | `github` | GitHub |
| `https://github.com/*/*/discussions/*` | `github` | GitHub |
| `https://x.com/*/status/*`, `https://twitter.com/*/status/*` | `tweet` | Tweet |
| `https://*` or `http://*` | `article` | URL |
| `*.pdf` (local path) | `pdf` | PDF |
| Local file path | `file` | File |
| `.ai/` or project directory | `internal` | Internal sync |
| No URL, no path | `clipboard` | Clipboard |

## Capture Modes

### URL (articles, blog posts, docs)

Use the `capture-url.sh` script:

```bash
"$PLUGIN_ROOT/scripts/capture-url.sh" "<url>" "$VAULT"
```

The script runs `defuddle parse <url> --markdown`, extracts the title and author from defuddle output, and prepends frontmatter. If defuddle is unavailable, fall back to `WebFetch` and manually convert to markdown.

Output file: `$RAW_DIR/external/YYYY-MM-DD-slugified-title.md`

### PDF (local documents)

1. Copy the PDF to `$RAW_DIR/external/` for archival.
2. Extract text with pandoc:

```bash
pandoc "<path>.pdf" -t markdown -o "$RAW_DIR/external/YYYY-MM-DD-slugified-title.md"
```

3. Prepend frontmatter to the extracted markdown. Set `source_type: pdf` and `source_url` to the original file path.

### YouTube (video transcripts)

Use the `capture-youtube.sh` script:

```bash
"$PLUGIN_ROOT/scripts/capture-youtube.sh" "<url>" "$VAULT"
```

The script runs `yt-dlp --write-auto-sub --sub-lang en --skip-download --convert-subs srt -o "%(title)s"`, then converts the `.srt` to markdown with timestamps stripped. If `yt-dlp` is unavailable, report the missing tool and stop.

Output file: `$RAW_DIR/external/YYYY-MM-DD-slugified-title.md` with `source_type: video`.

### GitHub (issues, PRs, discussions)

Use the `capture-github.sh` script:

```bash
"$PLUGIN_ROOT/scripts/capture-github.sh" "<url>" "$VAULT"
```

The script parses the URL to extract `owner/repo` and resource number, then calls:
- Issues: `gh api repos/{owner}/{repo}/issues/{number}`
- PRs: `gh api repos/{owner}/{repo}/pulls/{number}`
- Discussions: `gh api graphql` with discussion query

Converts the JSON response to markdown with title, body, labels, and comments. Set `source_type: github`.

### Tweet (X/Twitter threads)

Fetch the tweet content. Try these methods in order:
1. `WebFetch` the tweet URL with a readable user-agent
2. Parse the HTML for tweet text content

Format as markdown with author handle, timestamp, and thread structure. Set `source_type: tweet`. Save to `$RAW_DIR/external/YYYY-MM-DD-tweet-{author}-{id}.md`.

### File (local files)

Copy the file into `$RAW_DIR/external/` and add frontmatter:

```bash
cp "<source_path>" "$RAW_DIR/external/YYYY-MM-DD-original-filename.ext"
```

For text-based files (.md, .txt, .rst, .org), also create a `.md` version with frontmatter prepended. For binary files, create a companion `.md` sidecar with frontmatter and a reference to the binary.

### Internal sync (project directories)

Sync new or changed files from `.ai/` (or other specified project directories) into `$RAW_DIR/internal/`:

```bash
rsync -av --update --include="*.md" --exclude="*" "<source_dir>/" "$RAW_DIR/internal/<dir_name>/"
```

Do not add frontmatter to internal synced files — they retain their original format. Only sync files modified since the last capture (compare timestamps).

### Pull Requests (merged PRs → code changes)

Use the `capture-prs.sh` script:

```bash
"$PLUGIN_ROOT/scripts/capture-prs.sh" "<owner/repo>" "<vault_path>" "[since_date]"
```

Captures all merged PRs since a date (default: last 7 days). Each PR becomes a separate file in `raw/inbox/` with title, body, files changed, author, merge date. Set `source_type: pull-request`.

Modes:
- **Single PR**: `/wiki:capture --pr 79` → `capture-github.sh` with PR URL
- **Batch since date**: `/wiki:capture --prs-since 2026-04-08` → `capture-prs.sh`
- **Batch default (7 days)**: `/wiki:capture --prs` → `capture-prs.sh` without date

### Git Log (commit summaries)

Use the `capture-git-log.sh` script:

```bash
"$PLUGIN_ROOT/scripts/capture-git-log.sh" "<repo_path>" "<vault_path>" "[since_date]"
```

Captures all non-merge commits since a date as a single summary file in `raw/inbox/`. Includes commit hashes, messages, authors, dates, and diffstat. Set `source_type: git-log`.

Use for periods without PRs (direct commits to develop) or as a supplement to PR capture.

### Clipboard

Read clipboard content using `pbpaste` (macOS):

```bash
pbpaste > "$RAW_DIR/external/YYYY-MM-DD-clipboard-HHMMSS.md"
```

Prepend frontmatter with `source_type: clipboard` and `captured` date. Attempt to detect a title from the first heading or first line of content.

## Frontmatter Format

Every captured file in `raw/external/` gets YAML frontmatter:

```yaml
---
title: "Descriptive Title from Source"
source_type: article|video|pdf|github-issue|github-pr|github-discussion|github-repo|pull-request|git-log|tweet|file|clipboard
source_url: https://original-source-url.com/path
captured: YYYY-MM-DD
author: Author Name
---
```

Rules:
- `title` — extracted from source (page title, video title, issue title). If unavailable, derive from filename or first heading.
- `source_type` — one of the types listed above.
- `source_url` — original URL or file path. For clipboard, omit this field.
- `captured` — date of capture in ISO format.
- `author` — extracted from source when available. Omit if unknown.

## File Naming

Pattern: `YYYY-MM-DD-slugified-title.md`

Slugification rules:
- Lowercase
- Replace spaces and special characters with hyphens
- Remove consecutive hyphens
- Truncate to 80 characters
- Strip trailing hyphens

## Pipeline Shortcut

When the user passes `--ingest` (or says "capture and ingest"), run capture first, then immediately invoke the `ingest` skill on the captured file. This skips the manual two-step process.

Sequence: **capture** the source into `raw/` → **ingest** the captured file into `wiki/`.

## Error Handling

| Error | Action |
|-------|--------|
| Tool not installed (defuddle, yt-dlp, pandoc) | Report which tool is missing, suggest install command, stop |
| URL unreachable (4xx/5xx) | Report the HTTP status, do not create empty file |
| Duplicate filename in `raw/` | Append `-2`, `-3` suffix |
| Empty content extracted | Warn user, save with `[empty content]` placeholder |
| File exceeds 500KB after conversion | Warn user, proceed but note size in frontmatter as `large: true` |

## Directory Structure

```
raw/
├── external/          # All outside sources (articles, PDFs, videos, tweets, files, clipboard)
│   ├── 2025-01-15-karpathy-llm-wiki-pattern.md
│   ├── 2025-01-16-eip-4337-account-abstraction.md
│   └── 2025-01-16-vitalik-tweet-rollups.md
├── inbox/             # Batch captures (PRs, git logs) — temporary landing zone
│   ├── pr-79-feature-name.md
│   └── git-log-voidpay-2026-04-10.md
└── internal/          # Synced from project directories
    └── ai/
        ├── product.md
        └── knowledge/
```

## Checklist

Before finishing capture:
1. File exists in correct `raw/` subdirectory
2. Frontmatter is valid YAML with all required fields
3. Content is non-empty (or warned if empty)
4. Filename follows `YYYY-MM-DD-slug.md` pattern
5. If `--ingest` was requested, hand off to ingest skill
