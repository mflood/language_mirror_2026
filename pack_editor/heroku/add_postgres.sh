#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/add_postgres.sh <dev|prod>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

heroku addons:create heroku-postgresql:essential-0 -a "${APP_NAME}"

echo "Postgres added to ${APP_NAME}"
echo "Next: ./heroku/migrate.sh ${TARGET}"
