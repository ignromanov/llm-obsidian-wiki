#!/usr/bin/env bash
# Smoke test: init-vault.sh creates a v0.4.0 vault with all required dirs + hot.md.
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/test-config.md" <<'EOF'
---
vault_name: smoke-test
schema_version: 0.4.0
page_types:
  - concept
  - decision
  - source-summary
  - synthesis
  - comparison
  - open-question
raw_dirs:
  - external
  - internal
---
EOF

"$PLUGIN_ROOT/scripts/init-vault.sh" "$WORK/vault" "$WORK/test-config.md"

# Required dirs
[[ -d "$WORK/vault/wiki/concepts" ]]       || { echo "FAIL: concepts/ missing"; exit 1; }
[[ -d "$WORK/vault/wiki/decisions" ]]      || { echo "FAIL: decisions/ missing"; exit 1; }
[[ -d "$WORK/vault/wiki/sources" ]]        || { echo "FAIL: sources/ missing"; exit 1; }
[[ -d "$WORK/vault/wiki/synthesis" ]]      || { echo "FAIL: synthesis/ missing"; exit 1; }
[[ -d "$WORK/vault/wiki/_drafts" ]]        || { echo "FAIL: _drafts missing"; exit 1; }
[[ -d "$WORK/vault/wiki/contradictions" ]] || { echo "FAIL: contradictions missing"; exit 1; }
[[ -d "$WORK/vault/wiki/_logs" ]]          || { echo "FAIL: _logs missing"; exit 1; }
[[ -d "$WORK/vault/raw/external" ]]        || { echo "FAIL: raw/external missing"; exit 1; }

# .gitkeep for new dirs
[[ -f "$WORK/vault/wiki/_drafts/.gitkeep" ]]        || { echo "FAIL: _drafts/.gitkeep"; exit 1; }
[[ -f "$WORK/vault/wiki/contradictions/.gitkeep" ]] || { echo "FAIL: contradictions/.gitkeep"; exit 1; }
[[ -f "$WORK/vault/wiki/_logs/.gitkeep" ]]          || { echo "FAIL: _logs/.gitkeep"; exit 1; }

# hot.md present and substituted
[[ -f "$WORK/vault/wiki/hot.md" ]] || { echo "FAIL: hot.md missing"; exit 1; }
grep -q '^type: _hot$' "$WORK/vault/wiki/hot.md" || { echo "FAIL: hot.md frontmatter wrong"; exit 1; }
grep -q '{{NOW_ISO8601}}' "$WORK/vault/wiki/hot.md" \
  && { echo "FAIL: NOW_ISO8601 placeholder not substituted"; exit 1; }

# Config copied with schema_version preserved
[[ -f "$WORK/vault/wiki.config.md" ]] || { echo "FAIL: wiki.config.md missing"; exit 1; }
grep -q '^schema_version: 0.4.0' "$WORK/vault/wiki.config.md" || { echo "FAIL: schema_version != 0.4.0"; exit 1; }

# Git repo initialized
[[ -d "$WORK/vault/.git" ]] || { echo "FAIL: git not initialized"; exit 1; }

echo "smoke-init: OK"
