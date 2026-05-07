---
name: audit
description: This skill should be used when wiki-curator needs to perform a read-only health check of the vault, scanning for orphans, stale pages, source drift, contradictions, and tree-topology violations. Triggers on "audit wiki", "check health", "find issues", "wiki diagnostic".
---

# Audit — Wiki Health Check (Read-Only)

## Purpose

Read-only diagnostic scan of the vault. Produce structured health report with severity classification (P0/P1/P2). NO writes.

Used by wiki-curator only.

## Trigger phrases

- "audit wiki"
- "check vault health"
- "find issues"
- "wiki diagnostic"

## Inputs

- Optional `--scope` (whole vault default, or specific domain)

## Outputs

- Human-readable health report (markdown)
- 0 file writes

## Workflow

Run the aggregator:

```
${CLAUDE_PLUGIN_ROOT}/scripts/wiki-health.sh --vault $VAULT_PATH
```

This delegates to:

| Check | Script | Severity |
|---|---|---|
| Source drift (SHA mismatch raw vs sources) | verify-source-drift.sh | P0 |
| Tree topology (index >100, hub >15) | verify-tree-topology.sh | P1 |
| Contradictions (declared in relations) | detect-contradictions.sh | P1 |
| Orphans (no incoming wikilinks) | find-orphans.sh | P2 |
| Stale (forgetting curve + no incoming) | detect-stale.sh | P2 |

After running, **classify findings** in your report:

```
## Severity P0 (broken — block clean status)
- [item]: [file]:[line] — [reason]

## Severity P1 (degraded — should fix soon)
- [item]: ...

## Severity P2 (suggestion — quality improvement)
- [item]: ...

## Recommendations
- For each P0/P1, point to maintain skill action that would resolve it
- E.g., "Run wiki-curator maintain to split [[hub-X]] (18 members)"
```

## Quality gate

- Every finding has file path + line number (where applicable) + reason
- Severity classification consistent (no P1 mixed into P0)
- Report references `maintain` skill for fixable items

## Anti-patterns

- DO NOT write/edit anything
- DO NOT auto-fix (that's `maintain` skill)
- DO NOT load page contents into context unless required for the finding

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/wiki-health.sh` (aggregator)
- Underlying: find-orphans, detect-stale, detect-contradictions, verify-tree-topology, verify-source-drift
