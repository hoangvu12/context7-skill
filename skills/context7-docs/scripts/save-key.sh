#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/preflight.sh"

usage() {
  printf '%s\n' 'Usage: bash scripts/save-key.sh <c7-key>'
}

api_key=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$api_key" ]]; then
        api_key="$1"
        shift
      else
        printf 'Unexpected argument: %s\n' "$1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$api_key" ]]; then
  usage >&2
  exit 1
fi

if [[ ! "$api_key" =~ ^ctx7sk-[a-f0-9-]+$ ]]; then
  printf '%s\n' 'Invalid key format. Expected a value starting with ctx7sk-.' >&2
  exit 1
fi

context7_require_command curl
context7_resolve_python >/dev/null || {
  printf '%s\n' 'Missing required command: python' >&2
  exit 1
}

# Probe with a lightweight library search
probe_file="$(mktemp)"
trap 'rm -f "$probe_file"' EXIT

if ! http_code="$(curl -sS -o "$probe_file" -w "%{http_code}" -X GET "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks" -H "Authorization: Bearer ${api_key}")"; then
  printf '%s\n' 'Context7 probe failed due to a network or curl error.' >&2
  exit 1
fi

case "$http_code" in
  200)
    ;;
  401)
    printf '%s\n' 'Context7 rejected the key with 401 Unauthorized.' >&2
    exit 1
    ;;
  *)
    message="$(context7_python - "$probe_file" <<'PY'
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
    if [[ -n "$message" ]]; then
      printf 'Context7 probe failed (%s): %s\n' "$http_code" "$message" >&2
    else
      printf 'Context7 probe failed with HTTP %s.\n' "$http_code" >&2
    fi
    exit 1
    ;;
esac

mkdir -p "$CONTEXT7_CONFIG_DIR"

config_json="$(context7_python - "$api_key" <<'PY'
import json
import sys

data = {
    'api_key': sys.argv[1],
}

sys.stdout.write(json.dumps(data, indent=2))
PY
)"
printf '%s\n' "$config_json" > "$CONTEXT7_CONFIG_FILE"
chmod 600 "$CONTEXT7_CONFIG_FILE" 2>/dev/null || true

printf 'Saved Context7 config to %s\n' "$CONTEXT7_CONFIG_FILE"
