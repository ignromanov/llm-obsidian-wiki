---
name: browse
version: 0.1.0
description: "This skill should be used when the user wants to browse wiki contents, check what pages exist in the knowledge base, load domain context, or review the wiki index. Also use when an AI advisor needs to load context during session start. Triggers: browsing wiki, checking what's in knowledge base, loading context, reviewing wiki contents. Keywords: browse, index, overview, contents, list, catalog."
---

# Browse — Quick Wiki Overview

## Setup

Read `wiki.config.md` at the vault root. Extract `vault_name` → `$VAULT`, `plugin_root` → `$PLUGIN_ROOT`.

## Modes

### Section browse: `/wiki:browse <section>`

```bash
$PLUGIN_ROOT/scripts/section-browse.sh <vault_path> <section>
```

Output:
- `[section]` — name, count
- `[pages]` — `slug | title | tldr (truncated)` per page

Valid sections: concepts, entities, architecture, decisions, strategy, orgs, comparisons, open-questions, sources, synthesis.

### Full browse: `/wiki:browse`

```bash
$PLUGIN_ROOT/scripts/wiki-stats.sh <vault_path>
```

Parse `[sections]` block and present a summary table. Only drill into a section (via `section-browse.sh`) when the user requests it.

### Tag browse: `/wiki:browse --tags`

```bash
obsidian vault="$VAULT" tags sort=count counts
```

### Search browse: `/wiki:browse --search "<query>"`

```bash
$PLUGIN_ROOT/scripts/wiki-search.sh <vault_path> "<query>" [limit]
```

Output: `[results]` with inline TLDRs + `[related_tags]` for broadening.

## Fallback

If Obsidian CLI is unavailable, fall back to reading `index.md` at the wiki root.
