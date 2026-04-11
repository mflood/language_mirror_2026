#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/config.sh <dev|prod> [set KEY=VALUE ...] | [get KEY]}"
ACTION="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

if [[ -z "${ACTION}" ]]; then
  heroku config -a "${APP_NAME}"
  exit 0
fi

shift 2

if [[ "${ACTION}" == "set" ]]; then
  heroku config:set "$@" -a "${APP_NAME}"
  exit 0
fi

if [[ "${ACTION}" == "get" ]]; then
  KEY="${1:?Usage: ./heroku/config.sh <dev|prod> get KEY}"
  heroku config:get "${KEY}" -a "${APP_NAME}"
  exit 0
fi

echo "Unknown action: ${ACTION}"
exit 2
