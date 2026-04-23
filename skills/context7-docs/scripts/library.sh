#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/preflight.sh"

usage() {
  printf '%s\n' 'Usage: bash scripts/library.sh "<library-name>"'
}

query=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$query" ]]; then
        query="$1"
        shift
      else
        printf 'Unexpected argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$query" ]]; then
  usage >&2
  exit 1
fi

context7_preflight || exit_code=$?
if [[ -n "${exit_code:-}" ]]; then
  if [[ $exit_code -eq 2 ]]; then
    exit 2
  fi
  exit "$exit_code"
fi

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

encoded_query="$(python -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$query")"
if ! http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X GET "https://context7.com/api/v2/libs/search?libraryName=${encoded_query}&query=${encoded_query}" -H "Authorization: Bearer ${CONTEXT7_API_KEY}")"; then
  printf '%s\n' 'Context7 request failed due to a network or curl error.' >&2
  exit 1
fi

if [[ "$http_code" != "200" ]]; then
  message="$(context7_python - "$response_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as handle:
        data = json.load(handle)
except Exception:
    data = {}

message = ''
if isinstance(data.get('error'), dict):
    message = data['error'].get('message', '')
if not message:
    message = data.get('message', '') or ''

sys.stdout.write(str(message))
PY
)"
  case "$http_code" in
    401)
      printf '%s\n' 'Context7 authentication failed. Re-save the key with bash scripts/save-key.sh <key>.' >&2
      ;;
    429)
      printf '%s\n' 'Context7 rate limit reached. Retry with backoff.' >&2
      ;;
    *)
      if [[ -n "$message" ]]; then
        printf 'Context7 request failed (%s): %s\n' "$http_code" "$message" >&2
      else
        printf 'Context7 request failed with HTTP %s.\n' "$http_code" >&2
      fi
      ;;
  esac
  exit 1
fi

context7_python - "$response_file" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    data = json.load(handle)

results = data.get('results') or []

if not results:
    print('No libraries found.')
    sys.exit(0)

print(f'Found {len(results)} library(ies):')
print()

for lib in results:
    lib_id = lib.get('id') or lib.get('libraryId') or 'unknown'
    name = lib.get('title') or lib_id
    description = lib.get('description', '')
    versions = lib.get('versions', [])
    
    print(f'ID:   {lib_id}')
    print(f'Name: {name}')
    if versions:
        print(f'Versions: {", ".join(versions[:5])}')
    if description:
        print(f'Desc: {description[:200]}')
    print()
PY
