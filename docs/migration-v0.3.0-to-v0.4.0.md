# Migration v0.3.0 → v0.4.0 (User Guide)

This guide walks you through upgrading your existing v0.3.0 vault to v0.4.0.

## What changes for you

### Before (v0.3.0)

You typed `/wiki:capture <URL>`, `/wiki:ingest`, `/wiki:query "..."`, etc.

### After (v0.4.0)

You say what you want in natural language:
- "исследуй X" → wiki-researcher activates
- "что мы решили про Y" → wiki-advisor answers
- "наведи порядок" → wiki-curator audits + fixes
- "save this URL" → wiki-scribe captures

The two slash commands that remain:
- `/wiki:init` — bootstrap a new vault
- `/wiki:status` — quick metrics

## Required CLI tools (one-time install)

In addition to v0.3.0 tools (`defuddle`, `pandoc`, `jq`, `gh`):

```bash
uv tool install trafilatura   # new fallback web→md extractor
```

`trafilatura` replaces `pandoc` as the second-tier capture fallback (10× cleaner output).

## Run the vault migration

```bash
$PLUGIN_ROOT/scripts/migrations/v0.3.0-to-v0.4.0/migrate.sh --vault /path/to/your/vault
```

For vaults >1GB add `--confirm-backup`.

What happens:
- Backup at `<vault>.bak.v0.3.0/`
- New dirs: `wiki/_drafts/`, `wiki/contradictions/`, `wiki/_logs/`
- New file: `wiki/hot.md`
- `wiki.config.md` schema_version → 0.4.0, new sections added
- Each existing wiki page gets new frontmatter fields (tier, cluster, aliases, last_verified)
- Decision pages get `superseded_by`, `supersedes`
- Source pages get `quality`, `captured_by`
- Synthesis pages get `filed_from_query`

What stays the same:
- Page bodies (untouched)
- Custom fields you added (preserved)
- raw/ files (untouched)
- Old migration scripts (preserved for reference)

## After migration

Run a sanity check:

```
"наведи порядок"   # invokes wiki-curator audit
```

Expected: 0 P0 violations.

If you see issues:
- Check `wiki/_logs/migration-v0.4.0-*.md` for skipped pages
- Run `wiki-curator maintain` to apply auto-fixes

## Rollback

If things go wrong:

```bash
rm -rf /path/to/vault
mv /path/to/vault.bak.v0.3.0 /path/to/vault
```

Then pin plugin version `@0.3.0` until you decide to retry.

## Common questions

**Q: My `key_claims` are empty for old sources. Why?**
A: Re-extraction requires LLM context. Migration leaves them empty (fast, idempotent). Run `wiki-researcher` on a topic, or use `wiki-curator maintain` with explicit "extract key_claims for stale sources" — both will populate them lazily.

**Q: Can I skip the backup?**
A: Not recommended. The backup is fast (rsync). If your vault is huge (>1GB), pass `--confirm-backup` to acknowledge and proceed.

**Q: What if my `wiki.config.md` has my own custom fields?**
A: They're preserved. Migration only adds new sections (Tree topology / Quality gates / Privacy) if they don't exist.

**Q: Do my Obsidian wikilinks still work?**
A: Yes, all `[[wikilinks]]` are unchanged.
