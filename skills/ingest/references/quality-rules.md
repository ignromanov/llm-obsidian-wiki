# Quality Rules

- **Never fabricate** information not present in the source. Gaps = `> [!question]` callout.
- **Preserve exact quotes** for important claims using `>` blockquotes with source citation.
- **Every page** must have at least one `[[wikilink]]` to another page (no orphans).
- **Tags**: lowercase, hyphenated, reuse existing tags from the wiki when possible.
- **Status**: `draft` for pages created from a single source with incomplete coverage. `active` for multi-source or comprehensive pages.
- **Titles**: concise (2-5 words preferred). Use `aliases:` for longer variants.
- **TLDR**: always in `tldr:` frontmatter property, set via `obsidian` CLI. Never use `> [!tldr]` callouts.
- **Callouts**: `> [!warning]` for contradictions, `> [!question]` for open questions. No other callout types for content flags.
- **Page length**: Concept and entity pages should be concise (~500 words). Synthesis, decision, and strategy pages may be longer.
- **Confidence**: `low` for single-source pages, `medium` for 2+ corroborating sources, `high` for 3+ independent. Set during ingest.
- **Counter-arguments**: Concept pages should include `## Counter-Arguments & Gaps`. Ask: "What is the strongest objection?"
- **Relations**: When adding `> [!warning]` contradiction, also add `relations:` entry with `type: contradicts`.
- **Source hashes**: Computed at ingest via `shasum -a 256`. Lint detects drift when raw source changes.
- **Session handoff**: Log entries include `Deferred:` and `Next:` fields for session continuity.
