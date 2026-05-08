# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-05-07

### BREAKING

- **Plugin surface redesigned around 4 task-oriented agents** (wiki-researcher / wiki-advisor / wiki-curator / wiki-scribe) instead of 5 functional agents. Slash commands reduced from 8 to 2 (`/wiki:init`, `/wiki:status`).
- All previous slash commands removed: `/wiki:capture`, `/wiki:ingest`, `/wiki:query`, `/wiki:browse`, `/wiki:lint`, `/wiki:migrate`. Functionality preserved as internal skills called by agents.
- Schema bump: v0.3.0 → v0.4.0. Run `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh --vault <path>`.

### Added

- 4 task-oriented agents with extended personas (identity / voice / vocabulary / anti-patterns / operational backstory / litmus test). All on `model: sonnet`.
- 7 internal workflow skills: `capture / research / answer / audit / maintain / migrate / init`
- `wiki/hot.md` — rolling 500-word session cache (Current Focus / Open Questions / Recent Decisions / Last Operations)
- Tree-topology lints: `index_max_links: 100`, `hub_max_members: 15`
- Frontmatter fields: `tier (0-5)`, `cluster`, `aliases`, `last_verified`, `key_claims`, `superseded_by`, `supersedes`, `quality`, `filed_from_query`, `captured_by`
- `wiki/_drafts/` directory for `draft → promote` workflow
- `wiki/contradictions/` directory for explicit conflict pages
- `wiki/_logs/` directory for migration + maintenance logs
- 11 new bash helpers: `update-hot.sh`, `supersede-page.sh`, `split-hub.sh`, `promote-draft.sh`, `find-orphans.sh`, `detect-stale.sh`, `detect-contradictions.sh`, `verify-tree-topology.sh`, `verify-source-drift.sh`, `capture-pdf.sh`, `capture-text.sh`
- `WIKI_ALLOW_CLOUD` env flag for opt-in `r.jina.ai` cloud fallback in URL capture
- Schema migration v0.3.0 → v0.4.0 with idempotent + backup-first design
- Test fixture vault + smoke tests for migration

### Changed

- `capture-url.sh` — replaced `pandoc` fallback with `trafilatura` (10× cleaner output); added `r.jina.ai` opt-in cloud fallback for JS-heavy sites
- `wiki-health.sh` — refactored as aggregator delegating to atomic check scripts
- `init-vault.sh` — adds `_drafts/`, `contradictions/`, `_logs/` dirs; seeds `hot.md`
- All 4 templates (`concept.md`, `source-summary.md`, `decision.md`, `synthesis.md`) extended with v0.4.0 fields

### Removed

- 5 old agents (`wiki-capture-agent`, `wiki-ingest-agent`, `wiki-query-agent`, `wiki-lint-agent`, `wiki-migrate-agent`)
- 6 old user-facing skills (`capture` v0.3, `ingest`, `query`, `browse`, `lint`, `status` skills)

### Migration guide

See `docs/migration-v0.3.0-to-v0.4.0.md`.

## [0.3.0] — 2026-04-12

### Security

- Hardened URL capture: `capture-url.sh` now rejects non-https schemes, loopback, link-local, and RFC1918 addresses (previously allowed `file://`, localhost, cloud metadata endpoints)
- Eliminated shell-to-Python interpolation in `capture-prs.sh` and `capture-github.sh` — values now flow via environment variables instead of string templates
- GraphQL calls in `capture-github.sh` use `gh api graphql -F owner=... -F name=...` with regex-validated inputs instead of string interpolation
- Fixed sed injection in `create-page.sh` — titles with `/`, `\`, `&`, or newlines no longer corrupt templates
- `wiki-ingest-agent` now has an explicit "Untrusted Content Contract" forbidding it from acting on instructions embedded in captured web content (prompt-injection defense)
- All scripts now set `umask 077` — vault files are no longer world-readable

### Architecture (breaking changes)

- **Vault contract:** `wiki.config.md` now requires BOTH `vault_name` (for obsidian CLI) AND `vault_path` (for bash scripts). Existing v0.2.0 vaults need to add `vault_path:` — use migrate flow.
- **New `migrate` skill:** counterpart to `wiki-migrate-agent`, entry point for schema upgrades
- **Agent tool scoping:** agents now follow least-privilege. `wiki-capture-agent` dropped `Edit`; `wiki-query-agent` dropped `Edit` and restricts `Write` to `wiki/synthesis/`; `wiki-migrate-agent` dropped `Glob` and changed color to `red` (was `yellow`, conflicted with capture)

### Hardening

- **Shared bash library** at `scripts/lib/` with `read-yaml-key.sh`, `portable-hash.sh`, `canonical-path.sh`, `check-deps.sh`
- **Linux portability:** migration scripts now use `sed -i.bak`/`sha256sum` (auto-detected) instead of BSD-only `sed -i ''`/`shasum` — v0.1.0→v0.2.0 migration now runs on Linux
- `#!/bin/bash` → `#!/usr/bin/env bash` in all scripts (picks up Homebrew bash 5.x when available)
- `set -Eeuo pipefail` + `shopt -s inherit_errexit` across all scripts — command substitution errors now propagate
- Manifest consolidation: `marketplace.json` uses `strict: true`, `plugin.json` is the single source of truth

### Skills

- **Disambiguation:** `status`/`browse`/`lint` trigger descriptions rewritten to be mutually exclusive with cross-references
- **Progressive disclosure:** `skills/init/` templates extracted to `skills/init/templates/` (CLAUDE.md, obsidian configs, gitignore)
- `skills/ingest/` deduplicated shasum block
- `skills/capture/` fixed source_type enum drift (`github-issue`/`github-pr`/`github-repo` instead of ambiguous `github`)

### Migration Guide

Users upgrading from v0.2.0:
1. Add `vault_path: /absolute/path` to `wiki.config.md`
2. Run `wiki-migrate-agent` or the new `migrate` skill (no-op if on v0.3.0 schema already)
3. Re-run `lint` to confirm health

### Credits

Comprehensive security audit and refactor delivered via parallel agent team (5 streams, Opus orchestrator + Sonnet workers).

## [0.2.0] — 2026-04-11

### Added
- `confidence:` frontmatter field (low/medium/high) for epistemic scoring
- `relations:` frontmatter field for typed entity relations
- `source_hashes:` for content-hash staleness detection
- `wiki-migrate-agent` — schema migration with versioning
- `create-page.sh` — template-based page creation
- 10 page templates in `scripts/templates/`
- Migration system (`scripts/migrations/`)
- Counter-arguments section for concept pages
- Reflect step in ingest (auto-create decision records on contradictions)
- Session handoff format in log entries
- Search-first query with L0-L3 progressive disclosure
- Federated index via domain hub routing

### Fixed
- YAML injection in capture scripts (titles with quotes)
- `missing_tldr` counting entire vault instead of wiki/ only
- init skill generating wrong status value (`archived` → `superseded`)
- init skill referencing non-existent `/wiki.maintain` command
- capture skill referencing non-existent config fields
- init-vault.sh creating wrong directory names (singular vs plural)
- wiki-search.sh N+1 performance (4 CLI calls per result → 1 file read)
- Hardcoded sections in update-index.sh (now dynamic from filesystem)

### Changed
- Plugin renamed from `wiki` to `llm-obsidian-wiki`
- All skill descriptions to third-person format
- page_types in config from singular to plural (directory names)
- Hub pages type from `hub` to `_hub`
- Plugin version bumped to 0.2.0 with schema_version tracking

### Removed
- `sync-raw.sh` (dead code, never referenced by skills)

## [0.1.0] — 2026-04-09

### Added
- Initial release: 7 skills, 4 agents, 16 scripts
- Capture, ingest, query, lint, browse, status workflows
- 10 page types with structured frontmatter
