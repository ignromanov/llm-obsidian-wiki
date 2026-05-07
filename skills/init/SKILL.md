---
name: init
description: This skill should be used when bootstrapping a brand-new LLM Wiki vault — creates dir tree, seeds wiki.config.md, CLAUDE.md, hot.md, .gitignore. Invoked via /wiki:init slash command. Triggers on "init wiki", "create new vault", "scaffold knowledge base".
---

# Init — Vault Scaffold

## Purpose

Create new LLM Wiki vault from scratch. Single user-facing skill, invoked via `/wiki:init` slash command.

## Trigger phrases

- `/wiki:init` (slash command — only entry point)

## Inputs (collected interactively)

- `vault_name` (kebab-case slug, used in Obsidian CLI)
- `vault_path` (absolute path on disk)
- Optional: domain seed list

## Outputs

```
$vault_path/
├── wiki.config.md           # schema_version: 0.4.0
├── CLAUDE.md                # split into ingest / query / schema parts
├── .gitignore
└── wiki/
    ├── index.md
    ├── hot.md
    ├── _drafts/.gitkeep
    ├── contradictions/.gitkeep
    ├── _logs/.gitkeep
    ├── concepts/
    ├── decisions/
    ├── comparisons/
    ├── synthesis/
    ├── sources/
    └── open-questions/
```

## Workflow

1. **Collect inputs** via AskUserQuestion (vault_name, vault_path).
2. **Validate** target path is empty or doesn't exist.
3. **Run** `${CLAUDE_PLUGIN_ROOT}/scripts/init-vault.sh --name $vault_name --path $vault_path`.
4. **Print quick-start**:
   ```
   Vault scaffolded at $vault_path

   Quick start:
   - Add Obsidian vault: open $vault_path in Obsidian
   - First research: invoke wiki-researcher with "исследуй <topic>"
   - First capture: drag a URL/PDF and say "save this"
   - Status anytime: /wiki:status
   ```

## Quality gate

- All required dirs created
- `wiki.config.md` has `schema_version: 0.4.0` and required fields
- `wiki/hot.md` is empty rolling cache template
- `umask 077` honored (no world-readable files)

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/init-vault.sh`
