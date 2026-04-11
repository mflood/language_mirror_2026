#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?Usage: ./heroku/deploy.sh <dev|prod>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/target.sh"
resolve_target "${TARGET}"

heroku git:remote -a "${APP_NAME}" -r "${REMOTE_NAME}" >/dev/null 2>&1 || true

echo "Deploying pack_editor/ subtree to Heroku (main)..."
cd "$(git rev-parse --show-toplevel)"
git subtree push --prefix pack_editor "${REMOTE_NAME}" main

echo "Deployed. Next: ./heroku/migrate.sh ${TARGET}"
