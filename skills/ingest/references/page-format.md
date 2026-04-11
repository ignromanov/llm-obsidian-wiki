# Wiki Page Format

Every wiki page must follow this format exactly.

## Frontmatter Schema

```yaml
---
title: Page Title
type: concept|entity|architecture|decision|strategy|org|comparison|open-question|source-summary|synthesis
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: active|stale|superseded|draft
tldr: "One paragraph summary for progressive disclosure"
tags:
  - tag1
  - tag2
sources:
  - "[[raw/path/to/source|display name]]"
confidence: low|medium|high     # set by ingest based on source corroboration
relations:                       # optional — typed links to other pages
  - type: contradicts|supports|is-a|part-of|evolved_into|depends_on
    target: "[[page-name]]"
    note: "brief explanation"
source_hashes:                   # optional — for provenance tracking
  - path: "raw/path/to/source.md"
    sha256: "hash-value"
aliases:                    # optional
  - Alternative Name
---
```

## Page Body Template

```markdown
## Main content with [[wikilinks]]

Use Obsidian-flavored markdown: [[wikilinks]], callouts, YAML frontmatter.

## Sources
- [[src-source-name]] — what this source contributed
```

## Setting TLDR

After creating a page, set the `tldr` property atomically:

```bash
obsidian vault="$VAULT" property:set name=tldr value="..." path="<file>" silent
```

## Required Callouts

| Callout | When |
|---------|------|
| `> [!warning]` | Information contradicts another source |
| `> [!question]` | Open question, uncertain information, needs further research |

No other callout types for content flags.
