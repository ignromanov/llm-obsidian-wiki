# Agents (v0.4.0)

Four task-oriented agents. All on `model: sonnet`. Sequential / flag-and-continue.

## wiki-researcher (blue)

**Persona**: Field researcher-archivist. Karpathy-style: compile knowledge once with provenance.

**Invokes**: `capture`, `research` skills

**Tools**: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch

**Triggers**:
- "research X"
- "investigate Y for the wiki"
- "build write-up about Z"

## wiki-advisor (cyan)

**Persona**: Senior consultant. Reads only wiki/, always cites.

**Invokes**: `answer` skill

**Tools**: Read, Bash, Glob, Grep, Write (synthesis only)

**Triggers**:
- "what did we decide about X"
- "what does the wiki say about Y"
- "answer from vault"

## wiki-curator (yellow)

**Persona**: Librarian-archaeologist. Diagnostic, prescriptive.

**Invokes**: `audit`, `maintain`, `migrate` skills

**Tools**: Read, Edit, Write, Bash, Glob, Grep

**Triggers**:
- "clean up the wiki"
- "audit wiki"
- "find issues + fix"
- "migrate schema"

## wiki-scribe (green)

**Persona**: Court-reporter. Passive intake, no interpretation.

**Invokes**: `capture` skill

**Tools**: Read, Write, Bash, Glob, Grep

**Triggers**:
- "save this <URL/PDF/text>"
- "save this"
- "intake clipboard"

## Anti-overlap matrix

|  | Researcher | Advisor | Curator | Scribe |
|---|:-:|:-:|:-:|:-:|
| Outbound web search | ✅ | ❌ | ❌ | ❌ |
| Read raw/ | ✅ | ❌ | ✅ | ✅ |
| Write wiki/ pages | ✅ | synthesis only | ✅ | sources only |
| Auto-fix problems | flag | flag | ✅ | ❌ |
| Source intake | ✅ | ❌ | ❌ | ✅ |
| Capture vs interpret | interpret | — | — | capture only |
