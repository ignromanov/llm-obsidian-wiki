---
name: lint
version: 0.1.0
description: "This skill should be used when the user wants to check wiki health, find orphaned or stale pages, detect contradictions, broken wikilinks, or perform wiki maintenance. Also use when the user says 'check wiki', 'find orphans', 'wiki cleanup', 'fix broken links', or 'wiki maintenance'. Triggers: checking wiki health, finding orphans, stale pages, contradictions, maintenance, cleanup. Keywords: lint, health, orphan, stale, contradiction, broken link, maintenance."
---

# Lint — Wiki Health Check

## Setup

1. Read `wiki.config.md` at the vault root. Extract `vault_name` → `$VAULT`, `plugin_root` → `$PLUGIN_ROOT`.
2. Determine the mode from the invocation:
   - **Report** (default): `/wiki:lint` — report only, no file changes
   - **Fix**: `/wiki:lint --fix` — report + auto-fix issues
   - **Deep**: `/wiki:lint --deep` — re-read raw sources, check wiki drift, mark stale claims

## Checks

### Quick checks (automated)

Run the health script first — it covers orphans, broken links, dead ends, missing TLDR, and singleton tags in one call:

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh <vault_path>
```

Output `[counts]`: `orphans`, `unresolved`, `deadends`, `missing_tldr`, `singleton_tags`.

For verbose details on specific checks, use individual CLI commands:

```bash
obsidian vault="$VAULT" orphans                         # list orphan pages
obsidian vault="$VAULT" unresolved verbose               # broken links with sources
obsidian vault="$VAULT" deadends                         # pages with no outgoing links
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

For pages with `source_hashes:` in frontmatter, recompute `shasum -a 256` on each referenced raw file and compare. Mismatch = source changed since last ingest.

```bash
# Example check
stored_hash=$(grep -A1 "path: \"$raw_path\"" "$page" | grep sha256 | awk '{print $2}' | tr -d '"')
current_hash=$(shasum -a 256 "${VAULT_PATH}/${raw_path}" | awk '{print $1}')
[[ "$stored_hash" != "$current_hash" ]] && echo "DRIFT: $page ← $raw_path"
```

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
   $PLUGIN_ROOT/scripts/regenerate.sh <vault_path>
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
