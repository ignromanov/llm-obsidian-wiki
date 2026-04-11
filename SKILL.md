---
name: llm-obsidian-wiki
description: "Build persistent, compounding knowledge bases in Obsidian with LLMs. Captures sources, ingests into structured wiki pages, queries with citations, and lints for health. Inspired by Karpathy's LLM Wiki pattern."
---

# LLM Obsidian Wiki

> This is a **Claude Code plugin** with 7 skills, 5 agents, and 17 utility scripts.
> Installing just this SKILL.md gives you this overview — for full functionality, install the complete plugin.

## Install the Full Plugin

```bash
# Add as marketplace source
/plugin marketplace add ignromanov/llm-obsidian-wiki

# Install
/plugin install llm-obsidian-wiki@llm-obsidian-wiki
```

Or via GitHub:
```bash
claude --plugin-dir /path/to/llm-obsidian-wiki
```

## What You Get

| Skills | Agents |
|--------|--------|
| `/wiki:init` — scaffold vault | `wiki-ingest-agent` — batch process sources |
| `/wiki:capture` — collect sources | `wiki-capture-agent` — batch capture |
| `/wiki:ingest` — process into wiki | `wiki-query-agent` — autonomous research |
| `/wiki:query` — ask with citations | `wiki-lint-agent` — deep health check |
| `/wiki:lint` — health check | `wiki-migrate-agent` — schema migration |
| `/wiki:browse` — quick overview | |
| `/wiki:status` — metrics | |

## Architecture

Three layers with strict data flow:

- **Raw** (`raw/`) — immutable source material (articles, PDFs, transcripts)
- **Wiki** (`wiki/`) — LLM-maintained structured pages with wikilinks
- **Schema** (`CLAUDE.md`) — conventions, page types, workflows

Knowledge is compiled once and kept current, not re-derived on every query.

## Learn More

- **GitHub**: https://github.com/ignromanov/llm-obsidian-wiki
- **Inspired by**: [Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
