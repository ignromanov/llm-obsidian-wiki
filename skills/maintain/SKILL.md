---
name: maintain
description: This skill should be used when wiki-curator needs to apply auto-fixes for structural violations (orphans, missing fields, hot.md updates) and propose semantic fixes (contradictions, supersession, hub splits) with user confirmation. Triggers on "fix wiki issues", "auto-resolve", "split hubs", "promote drafts", "update hot.md".
---

# Maintain — Proactive Wiki Hygiene (Write)

## Purpose

Apply fixes from audit findings. Structural violations auto-fix; semantic violations propose with rationale and ask.

Used by wiki-curator.

## Trigger phrases

- "fix wiki issues"
- "auto-resolve P0 violations"
- "split hub X"
- "mark Y superseded by Z"
- "promote drafts"
- "update hot.md"

## Inputs

- Audit findings (from `audit` skill output) OR specific issue
- Mode: `auto` (apply structural fixes immediately) or `ask` (confirm each)

## Outputs

- Edits to `wiki/` (supersession links, hub splits, hot.md updates, promotion)
- Append entry to `wiki/_logs/maintain-<date>.md`

## Workflow

For each finding:

1. **Classify**:
   - **Structural** (auto-fixable): orphan-link suggestion, missing required frontmatter field, hot.md update, schema field, regenerate index/hubs
   - **Semantic** (needs review): contradictory key_claims, page merge candidates, supersession proposals

2. **Structural fix flow**:
   - Apply via appropriate script:
     - `update-hot.sh` for session cache
     - `regenerate.sh` for index regen
     - `update-hubs.sh` for hub regen
     - `promote-draft.sh` for `wiki/_drafts/<slug>.md` → published
   - Log to `_logs/maintain-<date>.md`

3. **Semantic fix flow**:
   - Propose with rationale: "X contradicts Y on claim Z. Recommend: mark Y as superseded by X, with note `<why>`."
   - Wait for user confirmation
   - On confirm: invoke `supersede-page.sh --vault $V --old Y --new X`
   - Log

4. **Hub split** (when audit reports hub >15):
   - Dry-run first: `split-hub.sh --vault $V --hub <slug> --dry-run`
   - Show proposal
   - On confirm: re-run with `--apply`
   - Update domain hub references

5. **After all fixes**: re-run `audit` skill. Verify P0 count is 0.

6. **Append log entry** to `wiki/_logs/maintain-YYYY-MM-DD.md`:

```markdown
## Maintain run YYYY-MM-DD HH:MM

### Auto-fixed (structural)
- [X]
- [Y]

### Confirmed by user (semantic)
- [Z]: rationale

### Skipped (declined)
- [W]: reason
```

## Quality gate

- 0 P0 findings after maintain run (verified by post-audit)
- Every semantic edit has logged rationale
- Backup not strictly required (git is the rollback)

## Anti-patterns

- DO NOT capture new sources (Scribe/Researcher)
- DO NOT synthesize new knowledge (Researcher)
- DO NOT answer questions (Advisor)
- DO NOT silently apply semantic fixes — always ask
- DO NOT write outside wiki/ (especially never to raw/)

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/update-hot.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/supersede-page.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/split-hub.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/promote-draft.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/regenerate.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/update-index.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/update-hubs.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/wiki-health.sh` (post-fix verification)
