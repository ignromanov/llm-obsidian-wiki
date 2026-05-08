# Architecture (v0.4.0)

## Three layers (preserved from v0.1.0)

```
raw/                  →    wiki/                  →    query (Advisor only)
(immutable, hashed)        (derived, traceable)         (cited synthesis)
```

Hard contracts:
1. Only `wiki-scribe` and `wiki-researcher` write to `raw/`. Append-only.
2. Every `wiki/<typed>/<slug>.md` has `cited_sources` or `derived_from`.
3. `wiki-advisor` reads only `wiki/`. Never `raw/`.
4. `key_claims` in `wiki/sources/<slug>.md` is the only "channel" from raw to synthesis.

## v0.4.0 addition: agent-first layer

```
┌─ AGENTS (4 task-oriented roles) ──────┐
│   wiki-researcher (blue, sonnet)      │
│   wiki-advisor (cyan, sonnet)         │
│   wiki-curator (yellow, sonnet)       │
│   wiki-scribe (green, sonnet)         │
└────────────┬──────────────────────────┘
             │  agent reads SKILL.md
             ▼
┌─ SKILLS (7 internal workflows) ────────┐
│   capture / research / answer / audit  │
│   maintain / migrate / init            │
└────────────┬──────────────────────────┘
             │  skill calls bash
             ▼
┌─ SCRIPTS (deterministic primitives) ───┐
│   scripts/lib/  scripts/migrations/    │
│   capture-*.sh, create-page.sh, ...    │
└────────────────────────────────────────┘
```

## Communication

- **User → agent**: natural language triggers via `<example>` blocks in agent description
- **Agent → skill**: agent reads `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md`
- **Skill → script**: invokes via Bash with `${CLAUDE_PLUGIN_ROOT}/scripts/...`
- **Agent ↔ agent**: NEVER direct. Sequential / flag-and-continue. If agent finds issue outside its lane, writes "X should be invoked" in final report; user decides.

## Tool boundaries

| Agent | Read | Write scope | Web | Bash |
|---|---|---|---|---|
| wiki-researcher | all | own new pages, no edits to existing concepts outside topic | ✅ | ✅ |
| wiki-advisor | wiki/ only | wiki/synthesis/ only | ❌ | ✅ |
| wiki-curator | all | all wiki/ (not raw/) | ❌ | ✅ |
| wiki-scribe | all | raw/ + wiki/sources/ only | ❌ | ✅ |

Path-scope is enforced at system-prompt level (no in-Claude-Code path-restriction tool yet).

## Frontmatter schema (v0.4.0)

See spec section 5.1 for diff vs v0.3.0.

Common fields on every wiki page:
- `name` (slug)
- `title`
- `type`
- `created`, `updated`
- `tier` (0-5)
- `cluster`
- `aliases`
- `last_verified`
- `confidence`
- `relations`
- `tags`
- `status` (active / deprecated / superseded / draft)
