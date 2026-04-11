#!/usr/bin/env bash
set -euo pipefail

# Resolve a deployment target ("dev"|"prod") into:
# - APP_NAME (Heroku app name)
# - REMOTE_NAME (git remote name used by heroku git:remote)
#
# Usage:
#   source ./heroku/target.sh
#   resolve_target "${1:?...}"
#   echo "${APP_NAME} ${REMOTE_NAME}"
resolve_target() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    echo "Usage: resolve_target <dev|prod>"
    return 2
  fi

  case "${target}" in
    dev)
      APP_NAME="language-mirror-editor-dev"
      REMOTE_NAME="heroku-dev"
      ;;
    prod)
      APP_NAME="language-mirror-editor"
      REMOTE_NAME="heroku-prod"
      ;;
    *)
      echo "Unknown target: ${target} (expected dev|prod)"
      return 2
      ;;
  esac
}
