#!/usr/bin/env bash
# Compute SHA256 of a file. Works on macOS (shasum) and Linux (sha256sum).
# Usage: hash=$(lib_sha256 "$file")
lib_sha256() {
  local file="$1"
  [[ -r "$file" ]] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    echo "ERROR: no sha256 tool available" >&2
    return 2
  fi
}

# Compute SHA256 of stdin. Works on macOS (shasum) and Linux (sha256sum).
# Usage: hash=$(printf '%s' "$text" | lib_sha256_stdin)
lib_sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "ERROR: no sha256 tool available" >&2
    return 2
  fi
}
