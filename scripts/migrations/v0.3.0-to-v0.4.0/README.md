# Migration v0.3.0 → v0.4.0

## What changes in your vault

- New dirs: `wiki/_drafts/`, `wiki/contradictions/`, `wiki/_logs/`
- New file: `wiki/hot.md` (rolling 500-word session cache)
- `wiki.config.md` `schema_version` bumped to `0.4.0`
- `wiki.config.md` new sections: tree topology thresholds, quality gates, privacy
- Every existing wiki page gets new frontmatter fields:
  - `tier` (0-5, inferred from path)
  - `cluster` (domain, inferred from parent dir)
  - `aliases: []`
  - `last_verified` (defaults to `created`)
- Decision pages: `superseded_by`, `supersedes`
- Source-summary pages: `quality: high`, `captured_by: legacy`
- Synthesis pages: `filed_from_query: null`

## What does NOT change

- Existing content (body of pages)
- Existing custom fields you added
- raw/ files (untouched)
- Migration scripts for older versions (preserved)

## Run

```bash
$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh --vault /path/to/your/vault
```

For vaults >1GB, add `--confirm-backup`.

## Properties

- **Idempotent** — safe to run twice (existing fields not overwritten)
- **Backup-first** — copies vault to `<vault>.bak.v0.3.0/` before changes
- **Lazy `key_claims`** — empty for existing sources; filled by next research/audit run
- **Skips unparseable YAML** — logs to `wiki/_logs/migration-v0.4.0-*.md`

## Rollback

If the migration fails or you want to revert:

```bash
mv /path/to/vault /path/to/vault.broken
mv /path/to/vault.bak.v0.3.0 /path/to/vault
```

**Do not `rm -rf` the live vault before the backup move is complete.** The two-step `mv` pattern is safe even if interrupted — the backup is never destroyed before the live vault is moved aside.
