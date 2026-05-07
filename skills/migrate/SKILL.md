---
name: migrate
description: This skill should be used when wiki-curator needs to upgrade a vault's schema_version to match the current plugin version. Triggers on "migrate wiki", "upgrade schema", "apply migration v0.X → v0.Y".
---

# Migrate — Schema Upgrade

## Purpose

Run schema migration scripts to upgrade vault from current `schema_version` to target. Idempotent. Backup-first.

Used by wiki-curator.

## Trigger phrases

- "migrate wiki"
- "upgrade schema to v0.4.0"
- "apply migration"
- "schema version mismatch"

## Inputs

- `--target` schema_version (default = latest plugin version)

## Outputs

- Vault upgraded with bumped `schema_version`
- Migration log in `wiki/_logs/migration-<chain>-<date>.md`
- Backup at `<vault>.bak.v<old>/`

## Workflow

1. **Read current schema_version** from `wiki.config.md`:
   ```
   current=$(lib_read_yaml_key "$VAULT_PATH/wiki.config.md" schema_version)
   ```

2. **Determine target version**:
   - If `--target` provided, use it
   - Else use plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`

3. **Find migration chain**:
   - Available scripts: `scripts/migrations/v<X>-to-v<Y>/migrate.sh`
   - Build chain from current → target (e.g., 0.1.0 → 0.2.0 → 0.3.0 → 0.4.0)
   - If no chain exists, error

4. **Run scripts in order**, idempotent:
   ```
   for migration in chain:
     "$migration" --vault "$VAULT_PATH"
   ```

5. **Verify post-conditions**: each migration script does its own verify; in addition, run `audit` skill at the end.

6. **Print summary** with chain executed, pages affected, log location.

## Quality gate

- Each migration idempotent (re-run = no-op)
- Backup exists at `<vault>.bak.v<old>/`
- Post-migration audit reports 0 P0 violations introduced

## Anti-patterns

- DO NOT skip the backup
- DO NOT manually edit `schema_version` field — only via migration scripts
- DO NOT try to migrate non-linearly (skip versions)

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/v0.1.0-to-v0.2.0.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/v0.2.0-to-v0.3.0.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh`
- After: `audit` skill for verification
