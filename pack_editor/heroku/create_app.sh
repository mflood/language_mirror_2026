#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/create_app.sh <dev|prod>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

heroku create "${APP_NAME}"

heroku stack:set heroku-24 -a "${APP_NAME}"
heroku config:set ENV="${TARGET}" -a "${APP_NAME}"

echo "Created app: ${APP_NAME}"
echo "Next: ./heroku/add_postgres.sh ${TARGET}"
