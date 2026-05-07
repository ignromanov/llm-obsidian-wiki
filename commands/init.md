---
name: init
description: Bootstrap a new LLM Wiki vault from scratch (scaffold dirs, seed config, hot.md)
---

Bootstrap a new LLM Wiki vault.

This command invokes the `init` skill which:
1. Asks for vault name + path
2. Creates dir tree under that path
3. Seeds `wiki.config.md` with `schema_version: 0.4.0`
4. Seeds `wiki/index.md` and `wiki/hot.md`
5. Drops `CLAUDE.md` (split into agent guidance / schema reference parts)
6. Prints quick-start instructions

After scaffolding, the vault is ready for first invocation of `wiki-researcher`, `wiki-scribe`, or any other agent.

Use the `init` skill at `${CLAUDE_PLUGIN_ROOT}/skills/init/SKILL.md` for the workflow.
