#!/usr/bin/env bash
# Read a top-level YAML key from a file.
# Usage: value=$(lib_read_yaml_key "$file" "vault_name")
# Handles: bare strings, "quoted", 'single-quoted', multi-word values.
# Prefers python3 + PyYAML if available, falls back to python3 stdlib, finally awk.
lib_read_yaml_key() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PY'
import sys, re
path, key = sys.argv[1], sys.argv[2]

def naive_scan():
    # Tolerant line scan, respects simple quoting. Used when PyYAML is missing
    # OR the frontmatter is malformed (e.g. an unquoted colon in a value).
    with open(path) as f:
        for line in f:
            m = re.match(rf'^{re.escape(key)}\s*:\s*(.*)$', line)
            if m:
                val = m.group(1).strip()
                if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                    val = val[1:-1]
                return val
    return None

v = ''
try:
    import yaml
    # Read only the FIRST YAML document. A markdown page's closing `---`
    # frontmatter fence is a YAML document separator, so feeding the whole
    # file to single-document safe_load() raises ComposerError on any page
    # with a body. safe_load_all + next() parses just the frontmatter.
    with open(path) as f:
        d = next(yaml.safe_load_all(f), None)
    if not isinstance(d, dict):
        raise ValueError("no frontmatter mapping")
    v = d.get(key, '')
except Exception:
    # PyYAML absent OR frontmatter unparseable — degrade to the line scanner
    # instead of dumping a traceback that pollutes audit output.
    v = naive_scan()

if v not in (None, ''):
    print(v)
PY
  else
    # last-resort: awk (loses quoted/multiword fidelity but better than nothing)
    awk -v k="$key" '
      $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); gsub(/"/, ""); print; exit }
    ' "$file"
  fi
}
