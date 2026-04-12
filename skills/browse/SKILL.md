---
name: browse
version: 0.2.0
description: "This skill should be used for BROWSING WIKI CONTENT — what pages exist, section contents, domain overview, loading context for advisors. Triggers: 'browse wiki', 'show me wiki', 'what's in the wiki', 'load context', 'list pages in <domain>', 'explore knowledge base', 'what pages exist', 'show me the knowledge base'. For counts/metrics (how many pages, coverage numbers, source counts) use the STATUS skill instead. For health/quality checks (orphans, stale pages, broken links, contradictions) use the LINT skill instead."
---

# Browse — Wiki Content Discovery

Load and navigate wiki content: pages within a section, full index overview, tag listing, or keyword search. Use this skill whenever the goal is reading or discovering wiki content rather than measuring it or auditing its quality.

## When to Use This Skill (vs. Others)

| Goal | Skill |
|------|-------|
| Read what pages exist, explore a domain, load context for an advisor session | **BROWSE** (this skill) |
| Get counts — how many pages, unprocessed sources, coverage percentages | **STATUS** |
| Find quality issues — orphans, stale pages, broken wikilinks, contradictions, source drift | **LINT** |

If the user says "what's in the wiki" or "show me the knowledge base" → use BROWSE.
If the user says "how many pages do I have" or "wiki stats" → use STATUS.
If the user says "check wiki health" or "find orphans" → use LINT.

## Setup

Read `wiki.config.md` at the vault root. Extract:
- `vault_name` → store as `$VAULT_NAME` (for `obsidian vault="$VAULT_NAME"` commands)
- `vault_path` → store as `$VAULT_PATH` (first positional argument to bash scripts)
- `plugin_root` → store as `$PLUGIN_ROOT` (for scripts like `$PLUGIN_ROOT/scripts/section-browse.sh`)

Both `vault_name` and `vault_path` must be read. Use `scripts/lib/read-yaml-key.sh` if available. Export both before any script invocation.

## Modes

### Section browse: `/wiki:browse <section>`

```bash
$PLUGIN_ROOT/scripts/section-browse.sh "$VAULT_PATH" <section>
```

Output:
- `[section]` — name, count
- `[pages]` — `slug | title | tldr (truncated)` per page

Valid sections: concepts, entities, architecture, decisions, strategy, orgs, comparisons, open-questions, sources, synthesis.

Present as a compact table. If the section is large (>20 pages), ask the user whether to paginate or filter by tag.

### Full browse: `/wiki:browse`

```bash
$PLUGIN_ROOT/scripts/wiki-stats.sh "$VAULT_PATH"
```

Parse the `[sections]` block and present a summary table showing each section name and page count. Only drill into a section (via `section-browse.sh`) when the user requests it — avoid loading all pages into context at once.

### Tag browse: `/wiki:browse --tags`

```bash
obsidian vault="$VAULT_NAME" tags sort=count counts
```

Lists all tags in the vault sorted by frequency. Use this when the user wants to explore the wiki by topic or wants to understand the tag landscape.

### Search browse: `/wiki:browse --search "<query>"`

```bash
$PLUGIN_ROOT/scripts/wiki-search.sh "$VAULT_PATH" "<query>" [limit]
```

Output: `[results]` with inline TLDRs + `[related_tags]` for broadening the search.

Use TLDRs to decide which pages the user is likely interested in. Offer to read full page content for any match.

## Decision Guidance

### Browse vs. Status

Both skills call `wiki-stats.sh` internally, but for different reasons:

- **Browse** uses the `[sections]` output to present a navigable content map. The goal is discovery — helping the user find and read pages.
- **Status** uses the `[totals]` and `[activity]` output to report metrics. The goal is measurement — counts, coverage, recency.

When the user asks "what's in the wiki" with no quantitative intent, choose Browse. When the user asks "how big is the wiki" or "what's the coverage", choose Status.

### Browse vs. Lint

Browse loads content without judgment. Lint evaluates content quality. If a user says "show me all orphan pages" they mean LINT (quality audit), not Browse. If they say "show me all concept pages" they mean BROWSE (content discovery).

### Browse vs. Query

Browse is index-level and section-level navigation. Query is question-answering — synthesizing across multiple pages to answer a specific question. If the user asks "what does the wiki say about X", use Query. If the user says "show me all pages about X", use Browse with `--search`.

## Fallback

If Obsidian CLI is unavailable, fall back to reading `index.md` at the wiki root directly. The index contains TLDRs and links for all pages and is maintained by `regenerate.sh`.

## Output

Always present browse results as a table or list with titles and TLDRs. Do not dump raw file paths. After presenting, offer to:
1. Read a specific page in full
2. Browse a specific section
3. Search for a keyword
