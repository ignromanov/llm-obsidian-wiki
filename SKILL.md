---
name: llm-obsidian-wiki
description: "Karpathy's LLM Wiki pattern, built for Claude Code. Long-term memory for Claude via Obsidian: captures URLs, PDFs, GitHub, YouTube and compiles them into a structured Obsidian vault with citations that grows smarter every session. Second brain, zettelkasten, and autonomous research assistant in one. Keywords: llm-wiki, obsidian-plugin, knowledge-base, compounding-knowledge, claude-code, pkm, llm-memory."
---

# LLM Obsidian Wiki

> **Karpathy's [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern — as a Claude Code plugin.** Turn Claude into a researcher that remembers, backed by an Obsidian vault that grows smarter every session.

In [his original gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), Andrej Karpathy sketched a simple but powerful idea: an **LLM-maintained personal wiki** where knowledge is compiled once, cross-linked, and kept current — so the LLM never re-derives what it's already learned. This plugin is a faithful implementation of that pattern, weaponized for **Claude Code** and built on top of **Obsidian**.

Every conversation with an LLM normally starts from zero. You paste the same context. You re-explain the same decisions. Your research dies in closed browser tabs. **`llm-obsidian-wiki` fixes this** by giving Claude a persistent, file-based memory that survives across sessions — structured as a plain-text Obsidian vault you can read, edit, git-version, and grep yourself. It's a **second brain Claude actively maintains** — a zettelkasten where the LLM does the filing, cross-linking, and drift detection for you.

## Live Example

```
You:     Research auth options for my Next.js app and write it up.

Claude:  [wiki-capture-agent]  → pulls 5 blog posts, 2 GitHub READMEs,
                                 1 YouTube talk into raw/external/
         [wiki-ingest-agent]   → synthesizes typed wiki pages:
                                 wiki/concepts/nextjs-auth-patterns.md
                                 wiki/comparisons/nextauth-vs-clerk-vs-supabase.md
                                 wiki/entity/better-auth.md
                                 wiki/open-questions/session-cost-past-10k-mau.md
         [regenerate]          → updates index.md + domain hub pages

         Done. 4 pages created, cross-linked with [[wikilinks]] and citations
         to raw sources. Confidence: medium (2+ corroborating sources).

─── A week later, new side project ───

You:     Which auth library should I use for this new Next.js app?

Claude:  [wiki-query] → reads wiki/comparisons/nextauth-vs-clerk-vs-supabase.md
                      → reads wiki/decisions/clerk-for-side-projects.md

         Clerk, if you want zero config and $0/month under 10k MAU — it ships
         social login, magic links, and organizations out of the box. Use
         NextAuth if you need full control of the DB schema. Avoid Supabase Auth
         unless you're already on Supabase for data. See [[clerk-for-side-projects]]
         for the full rationale. The open question [[session-cost-past-10k-mau]]
         still applies to this project too.
```

Notice what happened: **Claude didn't re-research.** It read its own structured notes in the Obsidian vault and answered with citations. That's the Karpathy compounding loop — knowledge **compiled once and kept current**, not re-derived on every query.

## What You Get

| Skills (8) | Autonomous Agents (5) |
|------------|------------------------|
| `/wiki:init` — scaffold a new Obsidian vault | `wiki-capture-agent` — batch source capture |
| `/wiki:capture` — collect URL/PDF/GitHub/YT/git-log | `wiki-ingest-agent` — autonomous page synthesis |
| `/wiki:ingest` — compile raw into typed wiki pages | `wiki-query-agent` — deep research + file-back |
| `/wiki:query` — ask with citations + synthesis | `wiki-lint-agent` — health + source drift detection |
| `/wiki:browse` — load domain context | `wiki-migrate-agent` — schema version upgrades |
| `/wiki:lint` — orphans, staleness, contradictions | |
| `/wiki:status` — metrics + unprocessed queue | |
| `/wiki:migrate` — apply schema migrations | |

Plus 17 portable bash utilities, a shared `scripts/lib/` helper library, 10 page-type templates (concept / entity / decision / strategy / comparison / synthesis / open-question / architecture / org / source-summary), and a versioned schema with migrations.

## How It Works

Three layers with strict data flow and clear ownership inside the Obsidian vault:

```
raw/                 →    wiki/                  →    query
(immutable sources)       (structured knowledge)       (cited synthesis)

• URLs + HTML             • concepts                   • "What did we decide?"
• PDFs                    • decisions (ADR-style)      • "What contradicts X?"
• GitHub PRs + issues     • comparisons                • Cross-page research
• YouTube transcripts     • synthesis pages            • Citation-backed answers
• Git logs                • open questions
• Clipboards              • organizations
```

**Raw** is append-only source material with SHA-256 provenance tracking.
**Wiki** holds LLM-maintained pages with YAML frontmatter, tags, `[[wikilinks]]`, confidence scores, and typed relations (`contradicts`, `supports`, `evolved_into`, `depends_on`).
**Query** reads the wiki — never raw sources directly — and answers with `[[wikilink]]` citations you can click through in Obsidian.

Contradictions surface as `> [!warning]` callouts with explicit `relations.type: contradicts` entries. Drift between raw and wiki is detected automatically by `wiki:lint` via hash comparison. Schema migrations travel with the plugin version, so upgrading the plugin upgrades your vault.

## Why This Exists

Other tools give Claude **retrieval**. The Karpathy LLM Wiki pattern gives Claude **memory with structure**:

- **vs raw RAG** — you get typed pages (`concept` / `decision` / `comparison` / `open-question`) instead of opaque chunks. LLM-navigable, human-auditable.
- **vs Notion AI** — files live in your Obsidian vault as markdown. Edit in Obsidian, git-version them, grep them, take them offline.
- **vs plain Obsidian** — the LLM maintains the structure for you: creates wikilinks, reuses tags, tracks confidence, detects contradictions, migrates schemas.
- **vs other Obsidian plugins** — ships both interactive skills AND autonomous agents for batch research and long-running synthesis.

This is **personal knowledge management (PKM) for the LLM era** — Karpathy's llm-wiki concept meeting the zettelkasten method, with Claude as the patient filer and Obsidian as the durable substrate.

## Install

```bash
# Via Claude Code marketplace
/plugin marketplace add ignromanov/llm-obsidian-wiki
/plugin install llm-obsidian-wiki@ignromanov

# Or local install
claude --plugin-dir /path/to/llm-obsidian-wiki
```

Then:

```bash
/wiki:init                              # scaffold a new Obsidian vault
/wiki:capture https://example.com/post  # capture a source
/wiki:ingest                            # compile raw into wiki pages
/wiki:query "what did we decide?"       # ask with citations
```

## What's New in v0.3.0

- **Security hardening** — `capture-url.sh` rejects non-https schemes and private/loopback IPs; shell injection fixed in capture and create scripts; prompt-injection defense added to the ingest agent
- **Vault contract** — `wiki.config.md` now requires both `vault_name` (for the Obsidian CLI) and `vault_path` (for scripts)
- **New `/wiki:migrate` skill** — upgrades existing vaults between plugin versions
- **Shared bash library** — `scripts/lib/` with portable helpers for YAML reading, SHA-256 hashing, and dependency checks
- **Linux portability** — migration scripts now work on both macOS and Linux

## Ideal For

Engineering decision tracking (ADRs), competitive landscape research, long-running projects that span months, founders tracking market intelligence, researchers building annotated bibliographies, teams who want every Slack discussion to settle into a durable note, and anyone tired of re-explaining the same context to Claude every Monday morning.

## Philosophy

- **Privacy > features** — everything lives on your disk, nothing leaves your machine
- **Files > databases** — plain markdown, editable in any tool, greppable forever
- **Compound > retrieve** — compile knowledge once, keep it current, never re-derive
- **Typed > chunked** — `concept` / `decision` / `comparison` beats opaque embeddings

## Learn More

- **GitHub**: [github.com/ignromanov/llm-obsidian-wiki](https://github.com/ignromanov/llm-obsidian-wiki)
- **Karpathy's original gist** (the pattern this plugin implements): [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- **Obsidian**: [obsidian.md](https://obsidian.md)
- **License**: MIT

---

*Keywords: karpathy llm wiki, llm-wiki, obsidian plugin, claude code plugin, knowledge base, compounding knowledge, second brain, zettelkasten, pkm, personal knowledge management, long-term memory for llm, llm memory, research assistant, obsidian vault, structured notes, markdown knowledge base, rag alternative, typed pages, note-taking with ai.*
