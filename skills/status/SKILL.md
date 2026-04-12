---
name: status
version: 0.2.0
description: "This skill should be used for WIKI METRICS AND COUNTS — how many pages exist, what's unprocessed, coverage numbers, source counts, type distribution. Triggers: 'wiki stats', 'how many pages', 'wiki size', 'coverage report', 'unprocessed count', 'wiki metrics', 'what needs processing', 'wiki activity'. For content discovery (what pages exist, reading content) use the BROWSE skill instead. For health/quality checks (orphans, stale, contradictions) use the LINT skill instead."
---

# Status — Wiki Metrics and Counts

Report quantitative metrics about the wiki: total page counts, per-type breakdowns, unprocessed raw sources, and last-activity timestamps. Use this skill whenever the goal is measuring the wiki rather than reading it or auditing its quality.

## When to Use This Skill (vs. Others)

| Goal | Skill |
|------|-------|
| Count pages, see coverage numbers, find how many sources are unprocessed | **STATUS** (this skill) |
| Read what pages exist, explore a domain, load context for an advisor | **BROWSE** |
| Find quality issues — orphans, stale pages, broken links, contradictions | **LINT** |

If the user says "wiki stats" or "how many pages do I have" → use STATUS.
If the user says "show me the wiki" or "what's in the knowledge base" → use BROWSE.
If the user says "check wiki health" or "find orphans" → use LINT.

## Setup

Read `wiki.config.md` at the vault root. Extract:
- `vault_name` → store as `$VAULT_NAME` (for `obsidian vault="$VAULT_NAME"` commands)
- `vault_path` → store as `$VAULT_PATH` (first positional argument to bash scripts)
- `plugin_root` → store as `$PLUGIN_ROOT` (for scripts like `$PLUGIN_ROOT/scripts/wiki-stats.sh`)

Both `vault_name` and `vault_path` must be read. Use `scripts/lib/read-yaml-key.sh` if available. Export both before any script invocation.

## Modes

### Basic (default): `/wiki:status`

Run the metrics script:

```bash
$PLUGIN_ROOT/scripts/wiki-stats.sh "$VAULT_PATH"
```

Output format — `[section]\nkey=value`:
- `[totals]` — wiki, raw, tags counts
- `[sections]` — per-type page counts (concepts, entities, etc.)
- `[activity]` — last_ingest, last_lint dates

Present as a compact table to the user.

### Unprocessed: `/wiki:status --unprocessed`

```bash
$PLUGIN_ROOT/scripts/find-unprocessed.sh "$VAULT_PATH"
```

Lists raw files without a corresponding `wiki/sources/src-*.md` page. These are sources that have been captured but not yet ingested into wiki pages.

### Health: `/wiki:status --health`

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH"
```

Output format:
- `[counts]` — orphans, unresolved, deadends, missing_tldr, singleton_tags
- `[summary]` — status=PASS or status=WARN

Exit code: 0 = all clear, 1 = issues found.

Present as a one-line summary: `Health: N orphans, N broken, N dead-ends, N missing-tldr`

If status=PASS, report: `Health: All clear`

Note: `--health` gives a numeric snapshot. For the full diagnostic (what exactly is wrong and how to fix it) use the LINT skill.

## Decision Guidance

### Status vs. Browse

Both skills can call `wiki-stats.sh` internally, but serve opposite goals:

- **Status** surfaces numbers — total pages, section counts, unprocessed count, activity dates. The user wants to know the size and shape of the wiki.
- **Browse** surfaces content — page titles, TLDRs, section listings. The user wants to navigate and read.

When a user asks "how big is my wiki", use Status. When they ask "what's in my wiki", use Browse.

### Status vs. Lint

Status `--health` produces a count summary (N orphans, N broken). Lint runs a full audit — it lists each orphan by name, finds contradictions, runs deep-mode source drift detection, and can auto-fix issues with `--fix`. Use Status for a quick pulse check; use Lint for a full quality review.

### Status vs. Ingest

`/wiki:status --unprocessed` shows what needs ingesting. It does not do the ingesting. After reviewing the list, the user can invoke the INGEST skill to process the listed files.

## Output Format

Present metrics as a table:

```
## Wiki Status — YYYY-MM-DD

| Metric          | Value |
|-----------------|-------|
| Wiki pages      | N     |
| Raw sources     | N     |
| Unprocessed     | N     |
| Tags            | N     |
| Last ingest     | date  |
| Last lint       | date  |

### By Type
| Type       | Pages |
|------------|-------|
| concepts   | N     |
| entities   | N     |
| ...        | ...   |
```

If `--health` was also requested, append:

```
### Health Snapshot
Health: N orphans, N broken links, N dead-ends, N missing-tldr
```
