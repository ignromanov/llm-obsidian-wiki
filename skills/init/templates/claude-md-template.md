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
