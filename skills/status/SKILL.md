---
name: status
version: 0.1.0
description: "This skill should be used when the user wants to see wiki metrics, check how many pages exist, find unprocessed raw sources, or get a quick health overview. Also use when the user says 'wiki stats', 'what needs processing', 'wiki coverage', or 'how big is the wiki'. Triggers: checking wiki status, seeing metrics, finding unprocessed sources, wiki health overview. Keywords: status, metrics, count, unprocessed, coverage, health."
---

# Status — Wiki Metrics and Health Summary

## Setup

1. Read `wiki.config.md` at the vault root. Extract `vault_name` → `$VAULT`, `plugin_root` → `$PLUGIN_ROOT`.

## Modes

### Basic (default): `/wiki:status`

Run the metrics script:

```bash
$PLUGIN_ROOT/scripts/wiki-stats.sh <vault_path>
```

Output format — `[section]\nkey=value`:
- `[totals]` — wiki, raw, tags counts
- `[sections]` — per-type page counts (concepts, entities, etc.)
- `[activity]` — last_ingest, last_lint dates

Present as a compact table to the user.

### Unprocessed: `/wiki:status --unprocessed`

```bash
$PLUGIN_ROOT/scripts/find-unprocessed.sh <vault_path>
```

Lists raw files without a corresponding `wiki/sources/src-*.md` page.

### Health: `/wiki:status --health`

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh <vault_path>
```

Output format:
- `[counts]` — orphans, unresolved, deadends, missing_tldr, singleton_tags
- `[summary]` — status=PASS or status=WARN

Exit code: 0 = all clear, 1 = issues found.

Present as a one-line summary: `Health: N orphans, N broken, N dead-ends, N missing-tldr`

If status=PASS, report: `Health: All clear`
