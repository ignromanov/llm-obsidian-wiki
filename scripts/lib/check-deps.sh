#!/usr/bin/env bash
# Verify required external commands are present.
# Usage: lib_check_deps gh jq curl || exit 1
lib_check_deps() {
  local missing=()
  local dep
  for dep in "$@"; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  if (( ${#missing[@]} > 0 )); then
    echo "ERROR: missing required commands: ${missing[*]}" >&2
    echo "Install them and retry." >&2
    return 1
  fi
  return 0
}
