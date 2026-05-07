#!/usr/bin/env bash
# URL validation and YAML escaping helpers shared by capture-* scripts.
# Source this file; do not execute directly.

[[ -n "${LIB_URL_SAFETY_LOADED:-}" ]] && return 0
LIB_URL_SAFETY_LOADED=1

# Escape a string for use inside a YAML double-quoted scalar.
# Handles: backslash, double-quote, newline, carriage-return, tab,
# and strips remaining control characters (0x00–0x1f except space 0x20).
lib_yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash must come first
  s="${s//\"/\\\"}"    # double quote
  # Newline → \n, carriage-return → \r, tab → space
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/ }"
  # Strip remaining control chars 0x00–0x1f (excluding space 0x20)
  # printf '%s' ... | tr -d removes the char range
  printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037'
}

# Validate that a URL is https-only and does not target internal/loopback addresses.
# Usage: lib_validate_https_url <url>
lib_validate_https_url() {
  local url="$1"
  [[ "$url" =~ ^https://[^[:space:]]+$ ]] || { echo "ERROR: only https:// URLs allowed" >&2; return 2; }
  local host="${url#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  case "$host" in
    localhost|127.*|0.0.0.0|::1) echo "ERROR: loopback blocked" >&2; return 2 ;;
    169.254.*) echo "ERROR: link-local blocked" >&2; return 2 ;;
    10.*|192.168.*) echo "ERROR: RFC1918 blocked" >&2; return 2 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "ERROR: RFC1918 blocked" >&2; return 2 ;;
  esac
}

# Resolve the hostname of a URL and validate the resulting IP against SSRF targets.
# Requires getent (Linux) or python3 (macOS/Linux). Falls back with a warning.
# Usage: lib_resolve_and_validate_ip <url>
lib_resolve_and_validate_ip() {
  local url="$1"
  local host="${url#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  local ip=""
  if command -v getent >/dev/null 2>&1; then
    ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
  elif command -v python3 >/dev/null 2>&1; then
    ip=$(python3 -c "import socket,sys; print(socket.gethostbyname(sys.argv[1]))" "$host" 2>/dev/null) || true
  else
    echo "WARN: no DNS resolver available, skipping IP validation" >&2
    return 0
  fi
  [[ -n "$ip" ]] || { echo "ERROR: DNS resolution failed for $host" >&2; return 2; }
  case "$ip" in
    127.*|0.0.0.0|::1) echo "ERROR: resolved to loopback: $ip" >&2; return 2 ;;
    169.254.*) echo "ERROR: resolved to link-local: $ip" >&2; return 2 ;;
    10.*|192.168.*) echo "ERROR: resolved to RFC1918: $ip" >&2; return 2 ;;
    172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) echo "ERROR: resolved to RFC1918: $ip" >&2; return 2 ;;
  esac
}
