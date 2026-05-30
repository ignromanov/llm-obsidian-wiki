#!/usr/bin/env bash
# Read top-level YAML keys from files.
# Usage (single-file):  value=$(lib_read_yaml_key "$file" "vault_name")
# Usage (multi-key):    lib_read_yaml_keys "$file" key1 [key2 ...]  → one value per line
# Usage (bulk):         find ... | lib_read_yaml_keys_bulk key1 [key2 ...]
#                       → one TAB-separated line per file: <path>\t<val1>\t<val2>...
# Handles: bare strings, "quoted", 'single-quoted', multi-word values.
# Prefers python3 + PyYAML if available, falls back to python3 stdlib, finally awk.

# Capture the bulk Python script into a variable at source time.
# python3 -c "$_LIB_YAML_BULK_PY" keeps stdin connected to the caller's pipe
# (no heredoc conflict), and argv[1:] stays as the requested keys.
if command -v python3 >/dev/null 2>&1; then
  _LIB_YAML_BULK_PY=$(cat <<'PYEOF'
import sys, re, os

keys = sys.argv[1:]

def naive_scan(path, keys):
    # Tolerant line scan, respects simple quoting. Used when PyYAML is missing
    # OR the frontmatter is malformed (e.g. an unquoted colon in a value).
    results = {k: '' for k in keys}
    try:
        with open(path) as f:
            for line in f:
                for k in keys:
                    if results[k] != '':
                        continue
                    m = re.match(r'^' + re.escape(k) + r'\s*:\s*(.*)$', line)
                    if m:
                        val = m.group(1).strip()
                        if (val.startswith('"') and val.endswith('"')) or \
                           (val.startswith("'") and val.endswith("'")):
                            val = val[1:-1]
                        results[k] = val
    except Exception:
        pass
    return results

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

def parse_file(path):
    if not os.path.isfile(path):
        return {k: '' for k in keys}
    try:
        if HAS_YAML:
            with open(path) as f:
                d = next(yaml.safe_load_all(f), None)
            if not isinstance(d, dict):
                raise ValueError("no frontmatter mapping")
            return {k: ('' if d.get(k) is None else str(d.get(k, ''))) for k in keys}
        else:
            return naive_scan(path, keys)
    except Exception:
        # PyYAML absent OR frontmatter unparseable — degrade to the line scanner
        return naive_scan(path, keys)

def normalize(v):
    # Normalize any tab/newline in a value to space so TSV stays parseable
    return re.sub(r'[\t\n\r]', ' ', v) if v else ''

for line in sys.stdin:
    path = line.rstrip('\n')
    if not path:
        continue
    results = parse_file(path)
    cols = [path] + [normalize(results.get(k, '')) for k in keys]
    print('\t'.join(cols))
PYEOF
)
fi

# lib_read_yaml_keys_bulk <key1> [<key2> ...]
# Reads newline-delimited file paths from STDIN.
# Emits one TAB-separated line per file: <path>\t<val_key1>\t<val_key2>...
# Single python3 spawn amortizes import cost across all files.
lib_read_yaml_keys_bulk() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "$_LIB_YAML_BULK_PY" "$@"
  else
    # last-resort: awk — one spawn per file (no python3 available)
    local k row val path
    while IFS= read -r path; do
      [[ -f "$path" ]] || continue
      row="$path"
      for k in "$@"; do
        val=$(awk -v key="$k" '
          $0 ~ "^"key":" { sub("^"key":[[:space:]]*", ""); gsub(/"/, ""); print; exit }
        ' "$path")
        row="$row	$val"
      done
      printf '%s\n' "$row"
    done
  fi
}

# lib_read_yaml_keys <file> <key1> [<key2> ...]
# Prints one value per line (empty line when key absent). Single python3 spawn.
lib_read_yaml_keys() {
  local file="$1"
  shift
  [[ -r "$file" ]] || return 1
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$@" <<'PY'
import sys, re
path = sys.argv[1]
keys = sys.argv[2:]

def naive_scan(keys):
    # Tolerant line scan, respects simple quoting. Used when PyYAML is missing
    # OR the frontmatter is malformed (e.g. an unquoted colon in a value).
    results = {k: '' for k in keys}
    with open(path) as f:
        for line in f:
            for k in keys:
                if results[k] != '':
                    continue
                m = re.match(r'^' + re.escape(k) + r'\s*:\s*(.*)$', line)
                if m:
                    val = m.group(1).strip()
                    if (val.startswith('"') and val.endswith('"')) or \
                       (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    results[k] = val
    return results

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
    results = {k: ('' if d.get(k) is None else str(d.get(k, ''))) for k in keys}
except Exception:
    # PyYAML absent OR frontmatter unparseable — degrade to the line scanner
    # instead of dumping a traceback that pollutes audit output.
    results = naive_scan(keys)

for k in keys:
    v = results.get(k, '')
    print(v if v not in (None,) else '')
PY
  else
    # last-resort: awk (loses quoted/multiword fidelity but better than nothing)
    local k
    for k in "$@"; do
      awk -v key="$k" '
        $0 ~ "^"key":" { sub("^"key":[[:space:]]*", ""); gsub(/"/, ""); print; exit }
      ' "$file"
    done
  fi
}

# lib_read_yaml_key <file> <key>  — thin wrapper over lib_read_yaml_keys.
# Prints value or nothing; returns 1 if file unreadable.
lib_read_yaml_key() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  local val
  val=$(lib_read_yaml_keys "$file" "$key")
  if [[ -n "$val" ]]; then
    printf '%s\n' "$val"
  fi
}
