---
name: query
version: 0.2.0
description: "This skill should be used when the user asks a question against the wiki, needs synthesis from multiple wiki pages, wants to search the knowledge base, or requests analysis of a topic. Also use when the user says 'find in wiki', 'what does the wiki say about', 'search knowledge', or 'analyze topic'. Triggers: asking questions, searching knowledge, needing synthesis, wanting analysis from wiki. Keywords: query, question, search, ask, find, synthesis, analysis."
---

# Query — Ask Questions Against the Wiki

## Setup

1. Read `wiki.config.md` at the vault root. Extract:
   - `vault_name` → store as `$VAULT_NAME` (for `obsidian vault="$VAULT_NAME"` commands)
   - `vault_path` → store as `$VAULT_PATH` (first positional argument to bash scripts)
   - `plugin_root` → store as `$PLUGIN_ROOT`

   Use `scripts/lib/read-yaml-key.sh` if available. Export both before any script invocation.

2. Determine the mode from the invocation:
   - **Interactive** (default): `/wiki:query "question"` — answer with citations, offer to file back
   - **Auto file-back**: `/wiki:query "question" --file-back` — answer saved automatically
   - **Research**: `/wiki:query "topic" --research` — deep multi-page analysis

## Workflow

> **Search-first principle**: Never load `index.md` into context. Always start with `wiki-search.sh` which returns ranked results with inline TLDRs. At 300+ pages, loading the full index overflows the context window.

### Step 0: Domain routing (optional)

If the question clearly maps to a single domain (e.g., "what orgs..." → orgs, "architecture of..." → architecture), load the domain hub first for orientation:

```bash
$PLUGIN_ROOT/scripts/section-browse.sh "$VAULT_PATH" <domain>
```

This returns the domain's page list with TLDRs — lighter than global search for domain-scoped questions.

### Step 1: Search + Triage

Run a combined search that returns results with inline TLDRs and related tags:

```bash
$PLUGIN_ROOT/scripts/wiki-search.sh "$VAULT_PATH" "<key terms>" [limit]
```

Output:
- `[results]` — `path | type | title | tldr (truncated)` per match, plus `results_total`
- `[related_tags]` — tags from matched pages with vault-wide counts (for broadening)

Use TLDRs to decide which pages warrant a full read. No extra calls needed for triage.

### Progressive Disclosure Levels

Use the minimum level needed for each page:

| Level | What loads | When to use | Token cost |
|-------|-----------|-------------|------------|
| L0 | title + tldr (from search) | Triage candidates | ~20 per page |
| L1 | Section headings only | Deciding whether to read fully | ~50 per page |
| L2 | Full page content | Synthesis, detailed analysis | ~500 per page |
| L3 | Page + all linked sources | Deep research, fact-checking raw claims | ~2000+ per page |

Start at L0 (search results). Promote to L1 by reading only headings. Promote to L2 for pages that pass triage. Promote to L3 only in `--research` mode or when a specific factual claim needs verification against the original raw source — load `sources:` frontmatter entries and read the corresponding `raw/` files.

### Step 1b: Tag Broadening (optional)

If `[related_tags]` shows a relevant tag with significantly more pages than `results_total`, broaden the search:

```bash
obsidian vault="$VAULT_NAME" search query="tag:#<tag-name>" path=wiki limit=20
```

Example: search for "security threats" returns 8 results, but `#security` has 46 pages. Tag broadening catches pages that don't contain the literal query terms but are thematically relevant.

### Step 2: Deep Read

Read full content of the pages selected in Step 1. Extract facts, claims, and relationships relevant to the question.

### Step 3: Graph Traversal

For each key page found in Steps 1-2, load its graph context:

```bash
$PLUGIN_ROOT/scripts/page-context.sh "$VAULT_PATH" <key-page>
```

This returns `[backlinks]` (inbound links with counts) and `[links]` (outbound). Use for 2nd-degree discovery: if page A is relevant and links to page B, page B may contain supporting detail.

If the query involves broader terms not covered by initial search, run a supplemental search:

```bash
obsidian vault="$VAULT_NAME" search query="<alternative terms>" path=wiki limit=10
```

### Step 4: Synthesize Answer

Compose an answer using `[[wikilinks]]` as inline citations. Every factual claim must cite at least one wiki page. If the wiki lacks information on part of the question, state the gap explicitly.

### Step 5: Interactive File-Back (Interactive mode only)

Ask the user: "File back as wiki page?" If yes, proceed to Step 6.

In `--file-back` mode, skip the question and proceed directly.

In `--research` mode, always proceed.

### Step 6: Create Synthesis Page

Write the answer to `wiki/synthesis/<slug>.md` with standard frontmatter:

```yaml
---
type: synthesis
status: active
created: YYYY-MM-DD
updated: YYYY-MM-DD
tldr: "One paragraph answer summary"
query: "<original question>"
sources:
  - "[[PageA]]"
  - "[[PageB]]"
tags:
  - synthesis
---
```

Set the `tldr` property via: `obsidian vault="$VAULT_NAME" property:set name=tldr value="..." path="<file>" silent`

### Step 7: Update Index

Run the regeneration script to include the new synthesis page:

```bash
$PLUGIN_ROOT/scripts/regenerate.sh "$VAULT_PATH"
```

### Step 8: Log

Append to `log.md`:

```markdown
## [YYYY-MM-DD] query | <question summary>
- Mode: interactive | file-back | research
- Pages read: N
- Synthesis: [[slug]] (if filed) | not filed
```

## Research Mode — Additional Steps

When invoked with `--research`:

1. After Step 3, identify **gaps** — aspects of the topic that wiki pages mention but do not explain, or that the topic logically requires but no page covers.
2. After Step 1 triage, promote key pages to L3 (page + raw sources) to verify that wiki claims accurately reflect the original source material.
3. After Step 5, append to the synthesis page:
   - `## Open Questions` — unanswered questions discovered during research
   - `## Suggested Sources` — types of raw sources that would fill the gaps
   - `## Follow-Up Queries` — specific `/wiki:query` invocations for deeper exploration
4. If contradictions are found between pages, note them with `> [!warning]` callouts citing both sides.
