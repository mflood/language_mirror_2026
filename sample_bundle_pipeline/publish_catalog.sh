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
# CloudFront distribution for turned.rip/lmaudio (also in ~/.langpack/publisher.yaml)
CF_DISTRIBUTION_ID="E3TEDMCIJGEXOE"

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

# Preflight: every remote pack referenced by the catalog must actually resolve.
# Publishing a catalog that points at a not-yet-uploaded pack gives all installs
# a 404 on import. Embedded packs (no manifestUrl) are skipped.
echo "🔍 Verifying referenced remote packs resolve..."
python3 - "$CATALOG" <<'PY'
import json, sys, urllib.request
cat = json.load(open(sys.argv[1]))
bad = []
for p in cat.get("packs", []):
    url = (p.get("source") or {}).get("manifestUrl")
    if not url:
        continue  # embedded pack — nothing to fetch
    try:
        urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=10)
    except Exception as e:
        bad.append(f"{p.get('id', '?')}: {url} -> {e}")
if bad:
    print("❌ Catalog references remote packs that don't resolve:", *bad, sep="\n  ")
    sys.exit(1)
print("   ✓ all referenced remote packs resolve")
PY

aws s3 cp "$CATALOG" "$S3_URI" \
    --content-type application/json \
    --cache-control "public, max-age=300"

# Invalidate the CDN so the new catalog propagates immediately rather than
# waiting out CloudFront's cached copy (the 5-min max-age is only an origin
# hint; without this, an earlier long-TTL cache entry can linger).
echo
echo "🌀 Invalidating CloudFront ($CF_DISTRIBUTION_ID)..."
aws cloudfront create-invalidation \
    --distribution-id "$CF_DISTRIBUTION_ID" \
    --paths "/lmaudio/featured_catalog.json" \
    --query 'Invalidation.Id' --output text

echo
echo "✅ Published. Verifying..."
curl -sS -o /dev/null -w "HTTP %{http_code}  %{size_download} bytes  %{content_type}\n" "$CDN_URL"
