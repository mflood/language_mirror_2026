#!/usr/bin/env bash
#
# Publish the in-app featured_catalog.json to S3 / CloudFront so existing
# installs pick it up on next launch (the iOS app prefers the remote copy
# over the embedded fallback when reachable).
#
# Usage:
#   ./sample_bundle_pipeline/publish_catalog.sh [--dry-run]
#
# Effect:
#   - Uploads LanguageMirror/.../Resources/featured_catalog.json to
#     s3://turned.rip/lmaudio/featured_catalog.json
#   - Sets Cache-Control: public, max-age=300 (5 min) so users see new
#     packs reasonably quickly without hammering the origin.
#

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$REPO_ROOT/LanguageMirror/LanguageMirror/2025-09-13/Resources/featured_catalog.json"
S3_URI="s3://turned.rip/lmaudio/featured_catalog.json"
CDN_URL="https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/featured_catalog.json"

if [ ! -f "$CATALOG" ]; then
    echo "❌ Missing catalog at: $CATALOG" >&2
    exit 1
fi

echo "Catalog: $CATALOG"
echo "Target:  $S3_URI"
echo "Public:  $CDN_URL"
echo

if [ "${1:-}" = "--dry-run" ]; then
    echo "--- DRY RUN ---"
    cat "$CATALOG"
    exit 0
fi

aws s3 cp "$CATALOG" "$S3_URI" \
    --content-type application/json \
    --cache-control "public, max-age=300"

echo
echo "✅ Published. Verifying..."
curl -sS -o /dev/null -w "HTTP %{http_code}  %{size_download} bytes  %{content_type}\n" "$CDN_URL"
