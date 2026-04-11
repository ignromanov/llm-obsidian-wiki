---
name: init
description: "This skill should be used when a user wants to create a new LLM Wiki vault, initialize a knowledge base from scratch, set up a wiki project, or bootstrap a compounding knowledge base. Also triggers on: 'create wiki', 'new vault', 'init wiki', 'start knowledge base', 'set up wiki structure', or any mention of creating a Karpathy-style LLM Wiki."
version: 0.1.0
---

# Init — LLM Wiki Vault Wizard

Interactive wizard that scaffolds a complete LLM Wiki vault: directory structure, schema, config, and git repo. The vault follows the three-layer pattern: `raw/` (immutable sources) -> `wiki/` (LLM-maintained pages) -> `CLAUDE.md` (schema).

All generated files use Obsidian Flavored Markdown: wikilinks, YAML frontmatter, callouts.

## Wizard Flow

Run 5 prompts via `AskUserQuestion`, then generate all files.

### Step 1: Project Name

Ask the user:

```
What is the project/wiki name?
This becomes the vault root directory name and appears in CLAUDE.md.
Example: "ml-research", "company-wiki", "reading-notes"
```

Store as `$PROJECT_NAME`.

### Step 2: Page Types

Ask the user which page types to include. Present the default 10 with checkboxes:

```
Which page types should the wiki support?
Default set (all selected):

1. concept     — Core ideas, definitions, mental models
2. entity      — External tools, technologies, protocols
3. architecture — System designs, data flows, infrastructure
4. decision    — ADRs, trade-off analyses, chosen paths
5. strategy    — Plans, roadmaps, positioning
6. org         — Team structure, processes, culture
7. comparison  — X vs Y evaluations, benchmarks
8. open-question — Unresolved problems, hypotheses
9. source-summary — Summaries of individual sources
10. synthesis   — Cross-source analyses, meta-insights

Enter numbers to toggle off, or "all" to keep defaults.
You can also add custom types (e.g., "tutorial", "glossary").
```

Store as `$PAGE_TYPES` array.

### Step 3: Raw Source Directories

Ask the user which raw source directories to create:

```
Which raw source directories do you need?
Default set:

1. knowledge — Articles, papers, reference material
2. specs     — Specifications, requirements, RFCs
3. meetings  — Transcripts, minutes, recordings
4. docs      — Official documentation, manuals
5. external  — Third-party content, scraped pages
6. inbox     — Temporary landing zone for batch captures (PRs, git logs)

Enter numbers to toggle off, "all" for defaults,
or add custom directories (e.g., "podcasts", "code-reviews").
```

Store as `$RAW_DIRS` array.

### Step 4: Capture Tools

Ask the user which capture tools are installed:

```
Which capture tools are available on this machine?
These determine which raw/ ingestion instructions go into CLAUDE.md.

1. defuddle — Web article extraction (HTML to clean markdown)
2. yt-dlp   — YouTube/video transcript download
3. pandoc   — Document conversion (PDF, DOCX, EPUB to markdown)

Enter numbers for installed tools, or "none".
```

Store as `$CAPTURE_TOOLS` array.

### Step 5: Confirmation

Present the full plan and ask for confirmation:

```
Ready to create:

  $PROJECT_NAME/
  ├── CLAUDE.md              (schema + instructions)
  ├── wiki.config.md         (vault settings, YAML frontmatter)
  ├── index.md               (vault entry point)
  ├── log.md                 (change log)
  ├── .gitignore
  ├── .obsidian/             (minimal Obsidian config)
  ├── wiki/                  (LLM-maintained pages)
  └── raw/                   (immutable sources)
      ├── $RAW_DIR_1/
      ├── $RAW_DIR_2/
      └── ...

Page types: [list selected types]
Capture tools: [list selected tools]

Proceed? (yes / edit / cancel)
```

If "edit", loop back to the relevant step. If "cancel", abort.

## File Generation

After confirmation, create all files in order.

### 1. Directory Structure

```
$PROJECT_NAME/
├── wiki/
├── raw/
│   ├── $RAW_DIR_1/
│   ├── $RAW_DIR_2/
│   └── ...
└── .obsidian/
```

### 2. CLAUDE.md

Generate tailored to chosen `$PAGE_TYPES` and `$CAPTURE_TOOLS`:

```markdown
# $PROJECT_NAME — LLM Wiki

> Schema and operating instructions for LLM agents maintaining this wiki.
> Source of truth: `wiki.config.md`

## Architecture

Three layers, strict data flow:

| Layer | Path | Mutability | Owner |
|-------|------|------------|-------|
| Raw Sources | `raw/` | Immutable after ingest | Human + capture tools |
| Wiki Pages | `wiki/` | LLM-maintained | LLM agents |
| Schema | `CLAUDE.md` | Human-approved; LLM may propose changes | Human + LLM co-evolve |

**Flow**: raw/ --> wiki/ --> CLAUDE.md (references back)

## Page Types

Every wiki page MUST have `type` in YAML frontmatter.

| Type | Template | Use When |
|------|----------|----------|
$PAGE_TYPE_TABLE

## Frontmatter Schema

All wiki pages require:

```yaml
---
type: $TYPE
title: "Human-readable title"
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: draft | active | stale | superseded
tldr: "One paragraph summary for progressive disclosure"
sources:
  - "[[raw/path/to/source]]"
tags:
  - tag1
  - tag2
---
```

## Conventions

- **Wikilinks**: Use `[[page-name]]` for all internal links, never markdown links
- **TLDR**: Every page has a `tldr:` frontmatter property (one paragraph summary). Set via `obsidian property:set name=tldr`.
- **Callouts**: Use Obsidian callouts for warnings, tips, questions
  - `> [!question]` for open questions
  - `> [!warning]` for caveats
  - `> [!info]` for context
- **Sources**: Every claim links back to `raw/` via `sources:` frontmatter
- **Atomicity**: One concept per page. Concept and entity pages should be concise (~500 words). Synthesis, decision, and strategy pages may be longer.
- **Naming**: lowercase-kebab-case for filenames, e.g. `wiki/transformer-architecture.md`

## Raw Source Ingestion

$CAPTURE_TOOLS_SECTION

## Log Protocol

After every wiki edit session, append to `log.md`:

```markdown
## YYYY-MM-DD — $SUMMARY
- Created: [[page1]], [[page2]]
- Updated: [[page3]]
- Sources ingested: [[raw/path]]
- Decisions: brief note
```

## Anti-Patterns

| Pattern | Why Bad |
|---------|---------|
| Editing raw/ files | Raw is immutable — create a wiki page instead |
| Wiki page without sources | Unverifiable claims, no provenance |
| Markdown links instead of wikilinks | Breaks Obsidian graph view |
| Pages without type frontmatter | Unclassified, breaks filtering |
| Giant pages (>500 words) | Split into atomic pages + synthesis |

## Optional Extensions

These tools enhance the wiki workflow but are not required:

- **[qmd](https://github.com/tobi/qmd)** — Local hybrid BM25/vector search for markdown. MCP server included. Useful as wiki grows beyond ~100 pages.
- **[Marp](https://marp.app/)** — Generate slide decks from markdown wiki pages. Obsidian plugin available.
- **[Dataview](https://github.com/blacksmithgu/obsidian-dataview)** — Query page frontmatter (tags, dates, status) with SQL-like syntax.
- **[Obsidian Web Clipper](https://obsidian.md/clipper)** — Browser extension for quick article capture to raw/.
```

For the `$CAPTURE_TOOLS_SECTION`, generate instructions only for tools the user confirmed installed:

- **defuddle**: `npx defuddle "$URL" > raw/external/$(date +%Y-%m-%d)-slug.md`
- **yt-dlp**: `yt-dlp --write-auto-sub --sub-lang en --skip-download -o "raw/external/%(title)s" "$URL"`
- **pandoc**: `pandoc -s input.pdf -t markdown -o raw/docs/output.md`

If no tools selected, write: "No capture tools configured. Add raw sources manually as markdown files."

### 3. wiki.config.md

This is the key config file that all other skills read to understand vault structure, page types, and conventions.

```markdown
---
project: $PROJECT_NAME
version: "1.0"
created: $TODAY
page_types: [$PAGE_TYPES as YAML list]
raw_dirs: [$RAW_DIRS as YAML list]
capture_tools: [$CAPTURE_TOOLS as YAML list]
wiki_dir: wiki
raw_dir: raw
log_file: log.md
index_file: index.md
naming: kebab-case
max_page_words: 500
link_style: wikilink
frontmatter: required
statuses: [draft, active, stale, superseded]
vault_name: $PROJECT_NAME
plugin_root: /path/to/wiki/plugin
---

# Wiki Configuration

This file is the single source of truth for vault settings.
All LLM Wiki skills read this file to adapt behavior.

## Editing

Change YAML frontmatter values to reconfigure the wiki.
Skills will pick up changes on next invocation.
```

### 4. index.md

```markdown
---
type: synthesis
title: "$PROJECT_NAME Index"
created: $TODAY
updated: $TODAY
status: active
sources: []
tags: [index, meta]
---

# $PROJECT_NAME

> [!info] Wiki Entry Point
> This page is the starting point for navigating the wiki.

## Page Types

$SECTION_PER_TYPE with `![[wiki/type-*.md]]` embed pattern or simple wikilinks

## Recent Activity

See [[log]] for the full change log.

## Getting Started

1. Add raw sources to `raw/`
2. Process sources into wiki pages in `wiki/`
3. Link related pages with wikilinks
4. Update this index as the wiki grows
```

### 5. log.md

```markdown
---
title: "Change Log"
created: $TODAY
updated: $TODAY
tags: [meta, log]
---

# Change Log

## $TODAY — Wiki initialized

- Vault created with `init` wizard
- Page types: $PAGE_TYPES_LIST
- Raw directories: $RAW_DIRS_LIST
- Capture tools: $CAPTURE_TOOLS_LIST
```

### 6. .gitignore

```gitignore
# Obsidian workspace (user-specific)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/appearance.json

# OS files
.DS_Store
Thumbs.db

# Temporary
*.tmp
*.swp
```

### 7. .obsidian/ Config

Create `.obsidian/app.json`:

```json
{
  "strictLineBreaks": false,
  "showFrontmatter": true,
  "defaultViewMode": "source",
  "livePreview": true,
  "readableLineLength": true
}
```

Create `.obsidian/core-plugins.json`:

```json
[
  "file-explorer",
  "global-search",
  "graph",
  "backlink",
  "outgoing-link",
  "tag-pane",
  "page-preview",
  "templates",
  "daily-notes",
  "command-palette",
  "editor-status"
]
```

### 8. Git Init

If the directory is not already inside a git repo, run:

```bash
cd "$PROJECT_NAME" && git init && git add -A && git commit -m "feat: initialize LLM Wiki vault"
```

If already in a git repo, skip init but still stage and commit the new files.

## Post-Init Message

After all files are created, present a summary:

```
Wiki vault "$PROJECT_NAME" created successfully.

Files:
  CLAUDE.md        — Schema (read this first in every session)
  wiki.config.md   — Settings (all skills read this)
  index.md         — Entry point
  log.md           — Change log (first entry recorded)

Next steps:
  1. Open the vault in Obsidian: open "$PROJECT_NAME"
  2. Add your first raw source to raw/
  3. Use /wiki:ingest to process raw sources into wiki pages
  4. Use /wiki:lint to check wiki health
```
