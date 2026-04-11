#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/logs.sh <dev|prod>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

heroku logs --tail -a "${APP_NAME}"
