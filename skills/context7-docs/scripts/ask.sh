#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/preflight.sh"

usage() {
  printf '%s\n' 'Usage: bash scripts/ask.sh "<library-id>" "<question>"'
  printf '%s\n' 'Example: bash scripts/ask.sh "/vercel/next.js" "How do middleware work?"'
}

library_id=""
query=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$library_id" ]]; then
        library_id="$1"
        shift
      elif [[ -z "$query" ]]; then
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

if [[ -z "$library_id" || -z "$query" ]]; then
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

request_body="$(context7_python - "$library_id" "$query" <<'PY'
import json
import sys

library_id, query = sys.argv[1:3]

payload = {
    'libraryId': library_id,
    'query': query,
}

sys.stdout.write(json.dumps(payload))
PY
)"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

if ! http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X POST "https://context7.com/api/docs" -H "Authorization: Bearer ${CONTEXT7_API_KEY}" -H "Content-Type: application/json" -d "$request_body")"; then
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

# Print the main answer / content
content = ''
if isinstance(data, dict):
    content = data.get('content') or data.get('answer') or data.get('response') or ''
    # Some APIs return a list of chunks/snippets
    if not content and 'results' in data:
        results = data['results']
        if isinstance(results, list):
            for item in results:
                text = item.get('content') or item.get('text') or item.get('snippet') or ''
                if text:
                    content += text + '\n\n'
else:
    content = str(data)

if content:
    print(content.strip())
else:
    print('No documentation content returned.')
    print()
    print('Raw response:')
    print(json.dumps(data, indent=2))

# Print sources if available
sources = []
if isinstance(data, dict):
    sources = data.get('sources') or data.get('citations') or []
    if not sources and 'results' in data:
        for item in data['results']:
            url = item.get('url') or item.get('source') or ''
            if url:
                sources.append(url)

if sources:
    print()
    print('Sources:')
    seen = set()
    for src in sources:
        if src not in seen:
            seen.add(src)
            print(f'- {src}')
PY
