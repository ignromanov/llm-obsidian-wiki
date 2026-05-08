---
name: status
description: Print wiki metrics (page counts by type, unprocessed sources, last-modified, schema version)
---

Print quick wiki metrics.

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/wiki-stats.sh --vault $VAULT_PATH
```

Read `vault_path` from `${VAULT_CONFIG:-./wiki.config.md}` (frontmatter field `vault_path`).

Expected output:
- Pages by type (concept, decision, source, synthesis, comparison, open-question)
- Unprocessed sources count
- Last-modified timestamp
- Schema version
- hot.md preview (first 5 lines)

No LLM reasoning. No file writes. Pure metrics.
