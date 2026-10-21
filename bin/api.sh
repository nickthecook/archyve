#!/usr/bin/env bash
# Usage: bin/api.sh /api/tools
#        bin/api.sh /api/tools/search_archive '{"queries": ["backups"]}'
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <path> [body]" >&2
  exit 1
fi

if [ -z "${ARCHYVE_API_KEY:-}" ]; then
  echo "Set ARCHYVE_API_KEY to a key from your account page." >&2
  exit 1
fi

url="${ARCHYVE_URL:-http://localhost:3000}/${1#/}"
args=(--silent --show-error --header "Authorization: Bearer $ARCHYVE_API_KEY")

if [ $# -eq 2 ]; then
  args+=(--header "Content-Type: application/json" --data "$2")
fi

curl "${args[@]}" "$url" | jq .
