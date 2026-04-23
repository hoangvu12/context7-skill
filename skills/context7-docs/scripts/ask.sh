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

encoded_lib="$(python -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$library_id")"
encoded_query="$(python -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$query")"

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

if ! http_code="$(curl -sS -o "$response_file" -w "%{http_code}" -X GET "https://context7.com/api/v2/context?libraryId=${encoded_lib}&query=${encoded_query}&type=json" -H "Authorization: Bearer ${CONTEXT7_API_KEY}")"; then
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

# Print code snippets
code_snippets = data.get('codeSnippets') or []
for snippet in code_snippets:
    title = snippet.get('codeTitle', '')
    description = snippet.get('codeDescription', '')
    language = snippet.get('codeLanguage', '')
    
    if title:
        print(f'## {title}')
    if description:
        print(description)
    
    code_list = snippet.get('codeList') or []
    for code_example in code_list:
        lang = code_example.get('language', language)
        code = code_example.get('code', '')
        if code:
            print(f'```{lang}')
            print(code)
            print('```')
    print()

# Print info snippets
info_snippets = data.get('infoSnippets') or []
for info in info_snippets:
    breadcrumb = info.get('breadcrumb', '')
    content = info.get('content', '')
    
    if breadcrumb:
        print(f'## {breadcrumb}')
    if content:
        print(content)
    print()

if not code_snippets and not info_snippets:
    print('No documentation content returned.')
    print()
    print('Raw response:')
    print(json.dumps(data, indent=2))
PY
