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
try:
    import yaml
    with open(path) as f:
        d = yaml.safe_load(f) or {}
    v = d.get(key, '')
    if v is not None:
        print(v)
except ImportError:
    # fallback: naive line scan that respects quotes
    with open(path) as f:
        for line in f:
            m = re.match(rf'^{re.escape(key)}\s*:\s*(.*)$', line)
            if m:
                val = m.group(1).strip()
                if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                    val = val[1:-1]
                print(val)
                break
PY
  else
    # last-resort: awk (loses quoted/multiword fidelity but better than nothing)
    awk -v k="$key" '
      $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); gsub(/"/, ""); print; exit }
    ' "$file"
  fi
}
