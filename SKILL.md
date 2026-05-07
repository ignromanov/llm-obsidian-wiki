---
name: llm-obsidian-wiki
description: "Karpathy's LLM Wiki pattern as a Claude Code plugin — agent-first edition. Four task-oriented agents (Researcher / Advisor / Curator / Scribe) maintain a structured Obsidian vault that compounds knowledge across sessions. Privacy-first, local-only by default, citations + confidence + supersession baked in. Keywords: llm-wiki, obsidian-plugin, knowledge-base, claude-code, pkm, llm-memory, agent-first."
---

# LLM Obsidian Wiki — agent-first edition

> **Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern, as a Claude Code plugin.** Four task-oriented agents maintain a persistent, citation-backed knowledge base in your Obsidian vault that grows smarter every session.

## Agents

| Agent | Persona | When to invoke |
|---|---|---|
| **wiki-researcher** | Field researcher-archivist. Karpathy-style: compile knowledge once with provenance | "research X", "investigate Y", "build write-up about Z" |
| **wiki-advisor** | Senior consultant. Reads only `wiki/`, always cites with `[[wikilinks]]` | "what did we decide about X", "answer from wiki", "what does the wiki say" |
| **wiki-curator** | Librarian-archaeologist. Lint, drift detection, supersession, hub split, schema migration | "clean up the wiki", "audit health", "fix issues", "migrate schema" |
| **wiki-scribe** | Court-reporter. Passive intake — preserves verbatim, no interpretation | "save this URL/PDF/clipboard", "save this" |

All agents on `model: sonnet`. Sequential / flag-and-continue communication.

## Slash commands

- `/wiki:init` — scaffold a new vault
- `/wiki:status` — quick metrics

## Skills (internal — invoked by agents)

`capture` / `research` / `answer` / `audit` / `maintain` / `migrate` / `init`

## What's new in v0.4.0

- **Agent-first UX** — talk to the system in natural language; Claude triggers the right agent
- **Extended personas** with voice / vocabulary / anti-patterns / litmus tests
- **Sonnet-only** for token economy
- **defuddle → trafilatura → r.jina.ai** privacy-first web→md stack (cloud opt-in)
- **hot.md** rolling 500-word session cache
- **Tree topology lints** — index ≤100 links, hubs ≤15 members
- **Confidence + supersession** in frontmatter
- **Claim-level citations** with raw quotes and anchors
- **Forgetting curve** for stale-page detection

## Install

```bash
/plugin marketplace add ignromanov/llm-obsidian-wiki
/plugin install llm-obsidian-wiki@ignromanov
```

Required CLI tools (one-time):
```bash
npm i -g defuddle-cli
uv tool install trafilatura
```

## Quick start

```
/wiki:init                              # scaffold new vault
"research nextjs auth options"          # wiki-researcher will pick up the request
"what did we decide about auth?"        # wiki-advisor answers with cites
"clean up the wiki"                     # wiki-curator audits + fixes
"save this URL: ..."                    # wiki-scribe captures
```

## Migration from v0.3.0

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh --vault /path/to/vault
```

See `docs/migration-v0.3.0-to-v0.4.0.md` for details.

## Philosophy

- **Privacy > features** — local-only by default, cloud opt-in only
- **Files > databases** — plain markdown, greppable, git-versioned
- **Compound > retrieve** — compile once, never re-derive
- **Agents > slash commands** — say what you want, not how to do it

## License

MIT
