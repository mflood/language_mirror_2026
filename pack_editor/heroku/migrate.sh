#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/migrate.sh <dev|prod>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

DATABASE_URL="$(heroku config:get DATABASE_URL -a "${APP_NAME}")"
if [[ -z "${DATABASE_URL}" ]]; then
  echo "DATABASE_URL not set for ${APP_NAME}. Did you run add_postgres.sh?"
  exit 1
fi

echo "Running migrations against ${APP_NAME}..."
for f in migrations/*.sql; do
  MIGRATION_NAME="$(basename "${f}")"
  ALREADY_APPLIED=$(psql "${DATABASE_URL}" -tAc \
    "SELECT 1 FROM schema_version WHERE migration_name = '${MIGRATION_NAME}'" 2>/dev/null || echo "")
  if [[ "${ALREADY_APPLIED}" == "1" ]]; then
    echo "  SKIP ${MIGRATION_NAME} (already applied)"
  else
    echo "  APPLY ${MIGRATION_NAME}..."
    psql "${DATABASE_URL}" -f "${f}"
    psql "${DATABASE_URL}" -c "INSERT INTO schema_version (migration_name) VALUES ('${MIGRATION_NAME}');"
    echo "  DONE ${MIGRATION_NAME}"
  fi
done

echo "Migrations complete."
