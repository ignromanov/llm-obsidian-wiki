---
name: capture
description: This skill should be used when an agent needs to ingest a source (URL, YouTube, GitHub, PDF, clipboard, session log) into the vault. Triggers when wiki-scribe or wiki-researcher needs to "capture", "save source", "intake", "file URL", or "hash and store".
---

# Capture — Universal Source Intake

## Purpose

Ingest one source into `raw/<type>/<slug>.<ext>` (immutable, SHA-256 hashed) and create `wiki/sources/<slug>.md` (source-summary with `key_claims[]`).

Used by wiki-scribe (primary, passive intake) and wiki-researcher (via research workflow).

## Trigger phrases (agent perspective)

- "capture this URL"
- "save this PDF"
- "intake source"
- "file clipboard"
- "hash and store this"
- "wiki-scribe should ingest X"

## Inputs

One of:
- URL (any https://)
- YouTube link
- GitHub link (issue / PR / repo)
- PDF (path or URL)
- Raw text (clipboard, session log, transcript)

## Outputs

Two files per capture:
1. `raw/<type>/<slug>.<ext>` — immutable, SHA-256 in frontmatter, full content
2. `wiki/sources/<slug>.md` — source-summary with `key_claims: [{quote, anchor, confidence}]`, `quality`, `captured_by`

## Workflow

1. **Detect source type** from URL or path:
   - `*.pdf` → capture-pdf.sh
   - `youtube.com/*` or `youtu.be/*` → capture-youtube.sh
   - `github.com/*/issues/*` or `*/pull/*` → capture-github.sh
   - `github.com/*/pulls` → capture-prs.sh
   - text without URL → capture-text.sh
   - other URL → capture-url.sh

2. **Invoke the appropriate script** with `--vault $VAULT_PATH` and `--source $INPUT`. Scripts handle SHA-256 and frontmatter.

3. **Extract `key_claims`** for source-summary:
   - If source <500 words: preserve full content as single claim
   - If 500–5000 words: top-5 verbatim quotes with anchors (paragraph index)
   - If >5000 words: top-10 quotes with anchors

4. **Set `quality` field** in source-summary:
   - `high` if extraction succeeded with >500 chars
   - `medium` if 200-500 chars (paywall preview, partial)
   - `low` if <200 chars or extraction errors

5. **Set `captured_by`** to invoking agent name (`wiki-scribe` or `wiki-researcher`).

## Web→MD stack (for capture-url.sh)

The script tries three extractors in order:

1. `defuddle` (Node CLI, MIT, local) — primary
2. `trafilatura` (Python CLI, Apache-2.0, local) — fallback if defuddle fails OR content <500 chars
3. `r.jina.ai` (cloud) — opt-in via env `WIKI_ALLOW_CLOUD=1`

If all three fail, exit 3 and tell user to provide content via `capture-text.sh` (manual clipboard).

## Quality gate

- Every output has SHA-256 in frontmatter
- `wiki/sources/<slug>.md` is in tier 4
- `key_claims` is never empty for sources >500 words (if empty, log warning)
- `captured_by` is set

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-url.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-youtube.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-github.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-prs.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-pdf.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-text.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/capture-git-log.sh`

## Anti-patterns

- DO NOT interpret content during capture (preserve verbatim)
- DO NOT synthesize across sources (that's research's job)
- DO NOT edit existing wiki pages (only create raw/ + wiki/sources/)
