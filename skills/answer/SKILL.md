---
name: answer
description: This skill should be used when wiki-advisor needs to answer a user question by searching the wiki, retrieving cited claims, and composing an answer with [[wikilink]] references. Triggers on "what do we know about X", "what did we decide", "answer from the wiki", "find in vault".
---

# Answer — Query + Cite

## Purpose

Answer user questions using only the wiki/ subtree as the source of truth. Compose answers with `[[wikilink]]` citations. For non-trivial questions, save synthesis to `wiki/synthesis/<topic>.md`.

Used by wiki-advisor only.

## Trigger phrases

- "what do we know about X"
- "what did we decide about Y"
- "answer from the wiki"
- "find in vault"
- "summarize what's filed under Z"

## Inputs

- User question (free text)

## Outputs

- Inline answer with `[[wikilink]]` cites
- Optionally: `wiki/synthesis/<slug>.md` (if non-trivial: ≥3 source pages OR new framing)

## Hard contract

- READ ONLY from `wiki/`, NEVER from `raw/`
- DO NOT use WebFetch / WebSearch
- DO NOT fabricate — if knowledge absent, flag "wiki-researcher should be invoked"
- DO NOT edit pages outside `wiki/synthesis/`

## Workflow

1. **Parse intent**:
   - Factual ("what is X") → retrieve concept + cite
   - Comparative ("X vs Y") → retrieve comparison page or build synthesis
   - Decision-needed ("which should I use") → retrieve decision pages, surface trade-offs

2. **Hub-route**:
   - Start at `wiki/index.md`
   - Identify domain hub (`wiki/<cluster>.md`)
   - Drill to relevant concepts/decisions

3. **Multi-stage retrieval** with claim-level granularity:
   - `${CLAUDE_PLUGIN_ROOT}/scripts/wiki-search.sh --vault $VAULT_PATH --query "<query>"`
   - For each candidate page, read `key_claims` first
   - Read full body only if claims insufficient

4. **Compose answer**:
   - State conclusion concisely
   - Each non-trivial claim followed by `[[wikilink]]`
   - Hedge with confidence: "according to [[X]] (confidence: medium)..."
   - Surface contradictions explicitly: "but [[Y]] disagrees on..."
   - Surface open questions: "open question — see [[Z]]"

5. **If non-trivial** (≥3 source pages OR new cross-page synthesis):
   - Write `wiki/synthesis/<slug>.md` with `filed_from_query: <YYYY-MM-DD>` and `key_claims`
   - Add to hot.md: `update-hot.sh --section operation --content "wiki-advisor: filed synthesis on <topic>"`

6. **If knowledge absent**:
   - Say so explicitly
   - Flag: "wiki-researcher should be invoked for [topic]"
   - Do NOT pad with general knowledge

## Quality gate

- Every non-trivial claim has `[[wikilink]]`
- Open questions surfaced when relevant
- Synthesis pages have `filed_from_query` and `key_claims`
- Confidence stated explicitly when claims are uncertain

## Anti-patterns

- DO NOT read raw/ (three-layer invariant)
- DO NOT go to web (researcher's job)
- DO NOT fabricate — flag instead
- DO NOT edit non-synthesis wiki pages
- DO NOT write synthesis for trivial questions (one-shot answer suffices)

## Scripts used

- `${CLAUDE_PLUGIN_ROOT}/scripts/wiki-search.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/page-context.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/section-browse.sh`
- `${CLAUDE_PLUGIN_ROOT}/scripts/create-page.sh` (for synthesis)
- `${CLAUDE_PLUGIN_ROOT}/scripts/update-hot.sh`
