---
name: ingest
version: 0.2.0
description: "This skill should be used when the user wants to process raw source files into wiki pages, summarize new sources for the knowledge base, compile raw materials into structured wiki entries, or cross-reference new information with existing pages. Triggers: 'ingest', 'process this source', 'add to wiki', 'summarize for wiki', 'unprocessed sources', 'update knowledge base from raw'."
---

# Ingest — Process Raw Sources into Wiki Pages

Transform raw source files into structured, cross-referenced wiki pages. Each source produces a source summary and updates or creates concept/entity/decision pages.

## Prerequisites

1. Read `wiki.config.md` at the vault root. It defines paths, page types, and two key values for CLI operations:
   - `vault_name` → store as `$VAULT_NAME` (for `obsidian vault="$VAULT_NAME"` commands)
   - `vault_path` → store as `$VAULT_PATH` (first positional argument to bash scripts)
   - `plugin_root` → store as `$PLUGIN_ROOT` (for scripts like `$PLUGIN_ROOT/scripts/update-index.sh`)

   Use `scripts/lib/read-yaml-key.sh` if available. Export both `$VAULT_NAME` and `$VAULT_PATH` before any script invocation.

2. Scan vault context — run stats and health baseline:

```bash
$PLUGIN_ROOT/scripts/wiki-stats.sh "$VAULT_PATH"        # totals, sections, activity
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH"       # orphans, unresolved, deadends baseline
obsidian vault="$VAULT_NAME" tags sort=count counts      # tag registry — reuse existing tags
```

Save the `[counts]` values from `wiki-health.sh` as baseline for post-ingest comparison.

## Modes

Determine the mode from the invocation:

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Single interactive** | `/wiki:ingest <file>` | Process one source. Discuss key takeaways with the user via `AskUserQuestion` before writing pages. The user guides what matters. |
| **Single auto** | `/wiki:ingest <file> --auto` | Process one source. Decide autonomously which concepts to extract and pages to create/update. No user interaction. |
| **Batch** | `/wiki:ingest --unprocessed` | Process all raw files lacking `wiki/sources/src-*.md` coverage. Run `$PLUGIN_ROOT/scripts/find-unprocessed.sh` to get the list. Process each file in auto mode. |
| **Domain** | `/wiki:ingest --domain <name>` | Like batch, but scoped to `raw/<name>/` subdirectory only. |

## Ingest Cycle (per source)

Execute these steps for each source file:

### Step 0: Auto-capture (if file is outside raw/)

If the source path is outside the `raw/` directory:

1. Determine the target: `raw/external/YYYY-MM-DD-slugified-name.md`
2. Copy the file to target location
3. Prepend YAML frontmatter to the copy:

```yaml
---
title: "Title from first heading or filename"
source_type: file
source_url: "<original path>"
captured: YYYY-MM-DD
---
```

4. Update the source path for all subsequent steps to use the `raw/` copy.

If the file is already in `raw/`, skip this step.

### Step 1: Read the raw source

Read the file from `raw/`. Note its path — all citations reference this path.

If the file exceeds ~2000 lines (Read tool default limit), read in chunks of 120-140 lines using `offset`/`limit` parameters. Read the entire file before proceeding to Step 2.

### Step 2: Discuss takeaways (interactive mode only)

Present 3-7 key takeaways extracted from the source. Use `AskUserQuestion` to ask which are most important, whether any should be skipped, and whether the user sees connections to existing wiki pages. Incorporate the user's guidance into all subsequent steps.

In auto mode, skip this step entirely.

### Step 3: Create the source summary

Create `wiki/sources/src-<slug>.md` with the full wiki page format (see below). The slug is the filename without extension and without date prefix. Example: `2026-03-17-competitive-landscape-q1.md` becomes `src-competitive-landscape-q1`.

The source summary page must:
- Set `type: source-summary` in frontmatter
- **Link to the raw file in `sources:` frontmatter field** — this is the contract `find-unprocessed.sh` uses to track which raw files are processed. A source summary without a `sources:` wikilink to its raw file will cause the raw file to appear as "unprocessed" forever. Format: `"[[raw/path/to/file.md|Display Name]]"`
- Set `tldr:` frontmatter property with a one-paragraph summary: `obsidian vault="$VAULT_NAME" property:set name=tldr value="..." path="<file>" silent`
- List all key concepts, entities, decisions, and open questions found in the source
- Use `[[wikilinks]]` to reference existing or to-be-created wiki pages

Set `confidence:` based on corroboration:
- First source for a claim → `confidence: low`
- If updating an existing page and new source independently corroborates existing claims → consider upgrading to `medium` or `high`

After writing the page, compute source hashes for provenance tracking:

```bash
shasum -a 256 "raw/path/to/source.md" | awk '{print $1}'
```

Add to frontmatter:
```yaml
source_hashes:
  - path: "raw/path/to/source.md"
    sha256: "<computed hash>"
```

### Step 4: Create or update wiki pages

For each key concept, entity, decision, or other notable item extracted from the source:

**If a wiki page already exists:**

Before editing, load page context:

```bash
$PLUGIN_ROOT/scripts/page-context.sh "$VAULT_PATH" <page>
```

This returns `[meta]` (title, tldr, status, type), `[backlinks]` (inbound links with counts), and `[links]` (outbound links). Use backlinks for cross-reference ideas.

Then apply this checklist for each existing page (all items required):

- [ ] Read the existing page
- [ ] Add new information from this source (do not duplicate existing content)
- [ ] Add the new source to the `sources:` frontmatter array
- [ ] Add a line to the `## Sources` section: `[[src-<slug>]] — what this source contributed`
- [ ] Update `updated:` date atomically: `obsidian vault="$VAULT_NAME" property:set name=updated value=YYYY-MM-DD file="<page>"`
- [ ] Add new `[[wikilinks]]` for any cross-references discovered (use backlinks output for ideas)
- [ ] If new information contradicts existing content, add a `> [!warning]` callout explaining the contradiction with citations to both sources
- [ ] If new source contradicts existing content, add a `relations:` entry with `type: contradicts`
- [ ] If new source supports/corroborates existing claims, add `type: supports` relation
- [ ] Add `source_hashes` entry using the hash computed in Step 3 — do not recompute

**If no wiki page exists:**
- Create it in the appropriate `wiki/<type>/` directory (see type determination below)
- Use the full wiki page format, including `confidence: low` and `relations: []` in frontmatter
- Include all information from the current source
- Add cross-references to related existing pages using `[[wikilinks]]`
- If information is uncertain or incomplete, add a `> [!question]` callout
- Add `source_hashes` entry using the hash computed in Step 3 — do not recompute

For **concept** pages, include a `## Counter-Arguments & Gaps` section:

```markdown
## Counter-Arguments & Gaps

- **Strongest objection**: [What is the strongest critique of this concept?]
- **What the source leaves unaddressed**: [Gaps in the source's coverage]
```

Ask explicitly during extraction: "What is the strongest objection to this? What does this source leave unaddressed?" If the source provides no basis for critique, write "No counter-arguments identified in source — needs corroboration."

### Step 4b: Reflect (when contradictions arise)

If Step 4 produced any of these situations:
- A `> [!warning]` contradiction callout was added
- An existing claim was overwritten or significantly revised
- A key decision was made about what to include or discard

Then create a decision record in `wiki/decisions/`:

```yaml
---
title: "Resolve: [brief description of the contradiction]"
type: decision
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: active
confidence: medium
tldr: "Brief description of the decision and rationale"
tags:
  - decision
  - reflect
sources:
  - "[[raw/path/to/new-source]]"
  - "[[raw/path/to/conflicting-source]]"
relations:
  - type: contradicts
    target: "[[page-with-contradiction]]"
---

## Problem

[What the contradiction or decision was]

## Options

1. [Option A — keep existing claim]
2. [Option B — accept new claim]
3. [Option C — note both as valid perspectives]

## Chosen

[Which option was chosen]

## Rationale

[Why — cite specific evidence from sources]
```

If no contradictions or significant decisions occurred, skip this step entirely.

### Step 5: Update index and hubs

```bash
$PLUGIN_ROOT/scripts/regenerate.sh "$VAULT_PATH"
```

Regenerates `index.md` from all pages' `tldr` properties, and updates `_hub.md` files in each wiki subdirectory.

### Step 6: Append to log (session handoff format)

Append an entry to `log.md` at the wiki root:

```markdown
## [YYYY-MM-DD] ingest | <source title>
- Source: `[[raw/path/to/file]]`
- Created: [[page-1]], [[page-2]]
- Updated: [[page-3]], [[page-4]]
- Decisions: [[decision-page]] (if reflect step fired)
- Deferred: [any contradictions or questions left unresolved]
- Next: [suggested follow-up actions for next session]
```

The `Deferred` and `Next` fields are the session handoff — they tell the next agent what to pick up.

### Step 7: Post-ingest verification

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH"
```

Compare `[counts]` values to the baseline from Prerequisites. If counts increased, investigate:
- `orphans` increased → add `[[wikilinks]]` from related pages or update `_hub.md`
- `unresolved` increased → create missing pages or fix typos in wikilinks
- `deadends` increased → add outgoing `[[wikilinks]]` to related content
- `missing_tldr` > 0 → set `tldr` property on new pages

### Step 8: Report

Output a summary:
- Source file processed
- Pages created (with paths)
- Pages updated (with what changed)
- Any contradictions or open questions flagged

## Wiki Page Format

See `references/page-format.md` for the exact frontmatter schema, page body template, and required callouts.

After creating a page, set the `tldr` property atomically:
```bash
obsidian vault="$VAULT_NAME" property:set name=tldr value="..." path="<file>" silent
```

## Determining Page Type

See `references/page-types.md` for the full type taxonomy and disambiguation rules. Key rule: when ambiguous, prefer the more specific type.

## Quality Rules

See `references/quality-rules.md` for the complete quality checklist. Key rules: never fabricate (use `> [!question]`), no orphans, reuse existing tags, set tldr via CLI.

## Batch Processing

When processing multiple files (batch or domain mode):

1. Run `$PLUGIN_ROOT/scripts/find-unprocessed.sh "$VAULT_PATH"` to get the file list.
2. Process files chronologically (oldest first) to build context incrementally.
3. After each file, existing pages may have been updated — use the latest version for subsequent files.
4. Write a single combined log entry per batch run listing all sources processed.
5. At the end, report total pages created, total pages updated, and any contradictions found across sources.
