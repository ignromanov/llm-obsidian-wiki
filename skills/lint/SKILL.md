---
name: lint
version: 0.2.0
description: "This skill should be used for WIKI HEALTH AND QUALITY CHECKS — find orphans, stale pages, broken wikilinks, contradictions, source-wiki drift, or run wiki maintenance/cleanup. Triggers: 'lint wiki', 'check wiki health', 'find orphans', 'stale pages', 'broken links', 'wiki cleanup', 'fix wiki', 'audit quality', 'wiki maintenance', 'contradiction check'. For metrics/counts (how many pages, coverage numbers) use the STATUS skill instead. For browsing content (what pages exist, reading content) use the BROWSE skill instead."
---

# Lint — Wiki Health and Quality Audit

Run quality checks against the wiki: find structural issues (orphans, broken links, dead ends), content issues (stale pages, contradictions, shallow pages), and source drift. Optionally auto-fix structural issues with `--fix`, or run a deep re-read of raw sources with `--deep`.

## When to Use This Skill (vs. Others)

| Goal | Skill |
|------|-------|
| Find quality issues — orphans, stale, broken links, contradictions, drift | **LINT** (this skill) |
| Get counts — how many pages, unprocessed sources, coverage percentages | **STATUS** |
| Read/navigate wiki content — what pages exist, load context | **BROWSE** |

If the user says "check wiki health", "find orphans", "fix broken links", "audit quality" → use LINT.
If the user says "how many pages" or "wiki stats" → use STATUS.
If the user says "show me the wiki" or "browse pages" → use BROWSE.

## Setup

Read `wiki.config.md` at the vault root. Extract:
- `vault_name` → store as `$VAULT_NAME` (for `obsidian vault="$VAULT_NAME"` commands)
- `vault_path` → store as `$VAULT_PATH` (first positional argument to bash scripts)
- `plugin_root` → store as `$PLUGIN_ROOT` (for scripts like `$PLUGIN_ROOT/scripts/wiki-health.sh`)

Both `vault_name` and `vault_path` must be read. Use `scripts/lib/read-yaml-key.sh` if available. Export both before any script invocation.

Determine the mode from the invocation:
- **Report** (default): `/wiki:lint` — report only, no file changes
- **Fix**: `/wiki:lint --fix` — report + auto-fix issues
- **Deep**: `/wiki:lint --deep` — re-read raw sources, check wiki drift, mark stale claims

## Checks

### Quick checks (automated)

Run the health script first — it covers orphans, broken links, dead ends, missing TLDR, and singleton tags in one call:

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH"
```

Output `[counts]`: `orphans`, `unresolved`, `deadends`, `missing_tldr`, `singleton_tags`.

For verbose details on specific checks, use individual CLI commands:

```bash
obsidian vault="$VAULT_NAME" orphans                         # list orphan pages
obsidian vault="$VAULT_NAME" unresolved verbose               # broken links with sources
obsidian vault="$VAULT_NAME" deadends                         # pages with no outgoing links
```

### Manual checks (require reading pages)

#### Stale

Find pages where `status: active` but `updated` frontmatter is older than 30 days from today.

#### Contradictions

Find pages containing unresolved `> [!warning]` callouts. These indicate known contradictions that have not been reconciled.

#### Shallow

Find pages with fewer than 200 words of body content (excluding frontmatter) that do not have `status: draft`.

#### Index Drift

Find `.md` files in `wiki/` that exist on disk but are not referenced in `index.md`.

#### Low Confidence + Active

Find pages where `confidence: low` and `status: active`. These are active pages based on a single source — they need corroboration.

#### Missing Counter-Arguments

Find concept pages (`type: concept`, `status: active`) that do not contain a `## Counter-Arguments` section. These may present claims without critical examination.

#### Untyped Contradictions

Find pages containing `> [!warning]` callouts but no `relations:` entry with `type: contradicts`. The contradiction is noted but not formally declared in the graph.

#### Source Hash Drift

For pages with `source_hashes:` in frontmatter, use `wiki-health.sh` to compare stored hashes against current raw source hashes. Mismatch means the raw source changed since last ingest.

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH" --check-hashes
```

If `wiki-health.sh` does not support `--check-hashes` yet, manually iterate: for each `source_hashes` entry in a page's frontmatter, retrieve the stored `sha256` value and compare against the current file hash. Pages with hash mismatch should be marked `status: stale`.

### Growth Suggestions (report mode only)

After all health checks, optionally suggest wiki growth opportunities:

1. **Unresolved concepts** — wikilinks in page text that point to non-existent pages (already covered by `unresolved` check, but frame as growth opportunity: "These topics are mentioned but lack dedicated pages")
2. **Research topics** — based on `> [!question]` callouts across the wiki, suggest topics that could benefit from new raw sources
3. **Source gaps** — wiki pages with only 1 source in `sources:` that would benefit from corroborating sources

Present as a separate "## Growth Opportunities" section in the lint report, after the main health table.

## Output Format

Present a structured report:

```markdown
# Wiki Lint Report — YYYY-MM-DD

| Check          | Count | Status |
|----------------|-------|--------|
| Orphans        | N     | PASS/WARN |
| Stale          | N     | PASS/WARN |
| Contradictions | N     | PASS/WARN |
| Broken Links   | N     | PASS/FAIL |
| Shallow        | N     | PASS/WARN |
| Tag Hygiene    | N     | PASS/WARN |
| Dead Ends      | N     | PASS/WARN |
| Missing TLDR   | N     | PASS/FAIL |
| Index Drift    | N     | PASS/WARN |
| Low Confidence | N     | WARN |
| Missing Counter-Args | N | WARN |
| Untyped Contradictions | N | WARN |
| Source Hash Drift | N | WARN |
| Growth Opps    | N     | INFO |

## Details
### Orphans
- [[PageA]] — no inbound links
...
```

Use `PASS` when count is 0, `WARN` when issues are advisory, `FAIL` when issues block wiki integrity (broken links).

## Fix Mode

When invoked with `--fix`, after reporting:

1. **Orphans** — Add orphaned pages to the appropriate section of `index.md`
2. **Stale** — Update `updated` frontmatter to today, add `> [!warning] Staleness review needed` callout at the top of each stale page
3. **Broken Links** — Create draft pages for each broken link target:
   ```yaml
   ---
   type: concept
   status: draft
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   tldr: "Draft page auto-created by lint. Needs content."
   tags: [auto-generated]
   ---
   ```
4. **Index Drift** — Regenerate index and hubs:
   ```bash
   $PLUGIN_ROOT/scripts/regenerate.sh "$VAULT_PATH"
   ```

5. **Source Hash Drift** — Mark drifted pages as `status: stale` and add `> [!warning] Source changed since last ingest — re-ingest recommended` callout.

Do NOT auto-fix contradictions, shallow pages, or tag hygiene — these require human judgment.

## Deep Mode

When invoked with `--deep`:

1. For each wiki page, identify its `sources:` frontmatter entries.
2. Re-read the corresponding raw files in `raw/`.
3. Compare key claims in the wiki page against the raw source.
4. If the wiki page omits significant information from the raw source, or if claims no longer match, add a `> [!warning] Drift detected` callout with specifics.
5. Mark pages with confirmed drift as `status: stale` in frontmatter and add a `> [!warning] Drift detected` callout with specifics.

Warn the user that deep mode is heavy and suggest running it as a background agent for large wikis.

## Log

Append to `log.md`:

```markdown
## [YYYY-MM-DD] lint | <mode> — <summary>
- Orphans: N, Stale: N, Contradictions: N, Broken: N, Shallow: N, Tags: N, Dead Ends: N, Drift: N
- Fixed: <list of auto-fixes applied> (fix mode only)
```
