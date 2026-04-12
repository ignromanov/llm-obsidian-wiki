#!/usr/bin/env bash
# Resolve path canonically (symlink-free, absolute). Works without GNU coreutils.
# Usage: p=$(lib_canonical_path "$path")
lib_canonical_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
  else
    # Last resort: cd + pwd -P
    if [[ -d "$path" ]]; then
      (cd -- "$path" && pwd -P)
    elif [[ -e "$path" ]]; then
      local dir file
      dir=$(dirname -- "$path")
      file=$(basename -- "$path")
      echo "$(cd -- "$dir" && pwd -P)/$file"
    else
      echo "$path"
    fi
  fi
}
