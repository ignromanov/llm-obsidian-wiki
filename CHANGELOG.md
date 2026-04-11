# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
