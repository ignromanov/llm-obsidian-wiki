# Skills (v0.4.0)

Seven internal workflow skills, invoked by agents (not directly by users).

| Skill | Used by | Purpose |
|---|---|---|
| `capture` | scribe, researcher | Universal source intake → raw/ + wiki/sources/ |
| `research` | researcher | Outbound discovery + ingest + cross-link + contradiction detection |
| `answer` | advisor | Query wiki + cite + optionally save synthesis |
| `audit` | curator | Read-only health check (orphans/stale/drift/topology) |
| `maintain` | curator | Apply structural auto-fixes + propose semantic fixes |
| `migrate` | curator | Schema upgrade (idempotent, backup-first) |
| `init` | (slash command) | Scaffold new vault |

Each SKILL.md lives in `skills/<name>/SKILL.md` and contains:
- Frontmatter (name, description with trigger phrases)
- Purpose
- Workflow (numbered steps)
- Quality gate
- Anti-patterns
- Scripts used
