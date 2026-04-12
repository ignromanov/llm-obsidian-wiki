---
name: migrate
version: 0.1.0
description: "This skill should be used when the user wants to upgrade their wiki schema after a plugin update, apply a migration between plugin versions, add missing frontmatter fields to existing pages, or check whether their vault is compatible with the current plugin version. Triggers: 'migrate wiki', 'upgrade schema', 'apply migration', 'version upgrade', 'bring wiki up to date', 'schema version mismatch', 'plugin update migration', 'update wiki schema', 'upgrade wiki'."
---

# Migrate Wiki Schema

Apply schema migrations between plugin versions to keep existing wiki vaults compatible with the current plugin release.

## When to Use

- Plugin was updated (e.g., v0.2.0 → v0.3.0) and existing pages need new frontmatter fields or structural changes.
- `wiki-health.sh` reports a schema version mismatch.
- User explicitly asks to migrate, upgrade, or bring the wiki up to date.

Do NOT use for content changes (fixing contradictions, editing page text) — that is LINT or INGEST. Migration is strictly structural.

## Migration Flow

### Step 1: Detect versions

Read `wiki.config.md` at the vault root. Extract:
- `vault_name` → `$VAULT_NAME`, `vault_path` → `$VAULT_PATH`, `plugin_root` → `$PLUGIN_ROOT`
- `schema_version` — current installed schema (e.g., `"0.2.0"`)

Read `$PLUGIN_ROOT/.claude-plugin/plugin.json` to get the target `version`.

If versions match — report "Wiki schema is up to date (v<version>)" and exit.

### Step 2: Safety backup

Before any changes:

```bash
# Git repo:
git -C "$VAULT_PATH" add -A && git -C "$VAULT_PATH" commit -m "chore: pre-migration backup (schema v<from> → v<to>)"

# Not a git repo:
cp -r "$VAULT_PATH" "${VAULT_PATH}.bak-$(date +%Y%m%d%H%M%S)"
```

Report the backup location before proceeding. For preview only, pass `--dry-run` (no files modified, no backup needed).

### Step 3: Run migration scripts

Scripts live in `$PLUGIN_ROOT/scripts/migrations/` named `v<from>-to-v<to>.sh`. Build the full chain (e.g., v0.1.0 → v0.2.0 → v0.3.0 runs two scripts in order). If any hop has no script, report the gap and stop.

```bash
$PLUGIN_ROOT/scripts/migrations/v<from>-to-v<to>.sh "$VAULT_PATH"
```

If a script exits non-zero, stop immediately and report the failure. Do not run subsequent scripts.

### Step 4: Dispatch wiki-migrate-agent

After deterministic scripts complete, dispatch `wiki-migrate-agent` for adjustments requiring LLM judgment — inferring missing field values, validating auto-populated fields, handling ambiguous renames. See `agents/wiki-migrate-agent.md`.

### Step 5: Update schema version

```bash
obsidian vault="$VAULT_NAME" property:set name=schema_version value="<target>" file="wiki.config.md"
```

### Step 6: Post-migration lint

```bash
$PLUGIN_ROOT/scripts/wiki-health.sh "$VAULT_PATH"
```

Report the health summary. If issues are found, suggest `/wiki:lint --fix`.

## Script Contract

| Rule | Requirement |
|------|-------------|
| Naming | `v<from>-to-v<to>.sh` (semver) |
| Args | First positional arg: `vault_path` |
| Idempotent | Re-running produces the same result |
| Cross-platform | Works on macOS AND Linux |
| Dry-run | `--dry-run` flag: print planned changes, apply nothing |
| Output | One line per change: `[APPLY]` or `[SKIP]` |
| Exit code | 0 = success, non-zero = failure |

## Available Scripts

- `scripts/migrations/v0.1.0-to-v0.2.0.sh` — adds `vault_path` and `schema_version` to `wiki.config.md` (D1 dual-field contract)
- Pending: `v0.2.0-to-v0.3.0.sh` — will ship with the first vault requiring migration after v0.3.0 release

## Safety

- Always back up before migrating. The backup is the rollback path — do not attempt automatic rollback on failure.
- Additive migrations (add fields) are low-risk. Destructive migrations (rename/remove fields) require explicit user confirmation.
- Never run migration scripts concurrently.

## Log

Append to `log.md`:

```markdown
## [YYYY-MM-DD] migrate | v<from> → v<to>
- Scripts applied: v<from>-to-v<to>.sh
- Pages modified: N
- Agent dispatched: yes/no
- Post-lint: PASS/WARN (N issues)
- Backup: <path or git commit hash>
```
