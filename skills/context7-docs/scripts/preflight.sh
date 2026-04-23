#!/usr/bin/env bash
set -euo pipefail

CONTEXT7_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT7_CONFIG_DIR="${HOME}/.config/context7"
CONTEXT7_CONFIG_FILE="${CONTEXT7_CONFIG_DIR}/config.json"
CONTEXT7_LEGACY_KEY_FILE="${HOME}/.context7"

context7_emit_auth_required() {
  printf '%s\n' 'CONTEXT7_AUTH_REQUIRED'
  printf '%s\n' 'Get a free API key at https://context7.com/dashboard'
  printf '%s\n' "Then run: bash ${CONTEXT7_SKILL_DIR}/scripts/save-key.sh <your-key>"
}

context7_require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    return 1
  fi
}

context7_resolve_python() {
  if [[ -n "${CONTEXT7_PYTHON_BIN:-}" && -x "${CONTEXT7_PYTHON_BIN}" ]]; then
    printf '%s' "$CONTEXT7_PYTHON_BIN"
    return 0
  fi

  local candidate
  for candidate in python python3 py; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  return 1
}

context7_python() {
  local python_bin
  python_bin="$(context7_resolve_python)" || {
    printf '%s\n' 'Missing required command: python' >&2
    return 1
  }

  "$python_bin" "$@"
}

context7_json_get() {
  local json_file="$1"
  local key="$2"

  context7_python - "$json_file" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r', encoding='utf-8') as handle:
        value = json.load(handle).get(key, '')
except FileNotFoundError:
    value = ''
except Exception:
    value = ''

if value is None:
    value = ''

sys.stdout.write(str(value))
PY
}

context7_strip_wrapping_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

context7_load_dotenv() {
  local dotenv_path="$1"
  local line key value

  [[ -f "$dotenv_path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#export }"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    value="$(context7_strip_wrapping_quotes "$value")"

    case "$key" in
      CONTEXT7_API_KEY)
        export CONTEXT7_API_KEY="$value"
        ;;
    esac
  done < "$dotenv_path"
}

context7_load_json_config() {
  [[ -f "$CONTEXT7_CONFIG_FILE" ]] || return 0

  export CONTEXT7_API_KEY="${CONTEXT7_API_KEY:-$(context7_json_get "$CONTEXT7_CONFIG_FILE" api_key)}"
}

context7_load_legacy_key() {
  [[ -f "$CONTEXT7_LEGACY_KEY_FILE" ]] || return 0
  export CONTEXT7_API_KEY="${CONTEXT7_API_KEY:-$(tr -d '\r\n' < "$CONTEXT7_LEGACY_KEY_FILE")}"
}

context7_validate_key_format() {
  [[ -n "${CONTEXT7_API_KEY:-}" && "${CONTEXT7_API_KEY}" =~ ^ctx7sk-[a-f0-9-]+$ ]]
}

context7_preflight() {
  context7_require_command curl
  context7_resolve_python >/dev/null || {
    printf '%s\n' 'Missing required command: python' >&2
    return 1
  }

  if context7_validate_key_format; then
    return 0
  fi

  context7_load_dotenv "${PWD}/.env"
  if context7_validate_key_format; then
    return 0
  fi

  context7_load_json_config
  if context7_validate_key_format; then
    return 0
  fi

  context7_load_legacy_key
  if context7_validate_key_format; then
    return 0
  fi

  context7_emit_auth_required
  return 2
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  context7_preflight
fi
