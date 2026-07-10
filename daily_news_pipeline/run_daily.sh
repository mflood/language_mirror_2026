#!/usr/bin/env bash
#
# Daily news pipeline driver. Runs steps 0→6 (incl. 2b translate) in sequence. Logs all output to
# work/<date>/run.log AND echoes to stdout. Exits non-zero on any step failure.
#
# Usage:
#   ./run_daily.sh                  # today (Eastern), dry-run by default
#   ./run_daily.sh --commit         # actually spend on Claude + ElevenLabs + S3
#   ./run_daily.sh --date 2026-05-24 --commit
#
# Pre-reqs:
#   - source the .env at the repo root so ANTHROPIC_API_KEY and
#     ELEVENLABS_API_KEY are available
#   - AWS credentials configured (aws configure list)
#   - voices.yaml populated with real ElevenLabs voice ids

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Unattended-run hardening (launchd provides a bare environment):
# explicit venv python + ffmpeg on PATH.
PY="$HOME/.pyenv/versions/six_wands_language_mirror/bin/python"
[ -x "$PY" ] || PY="$(command -v python3)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

COMMIT_FLAG=""
DATE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --commit) COMMIT_FLAG="--commit"; shift ;;
        --date)   DATE="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$DATE" ]; then
    # Default to today in US/Eastern (matches step scripts)
    DATE=$(TZ=America/New_York date +%Y-%m-%d)
fi

WORK_DIR="$HERE/work/$DATE"
mkdir -p "$WORK_DIR"
LOG="$WORK_DIR/run.log"

# Source secrets from the repo root .env if it exists
if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$REPO_ROOT/.env"
    set +a
fi

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

step() {
    local label="$1"; shift
    log "═══ $label ═══"
    if "$@" 2>&1 | tee -a "$LOG"; then
        log "✓ $label"
    else
        log "❌ $label failed"
        exit 1
    fi
}

log "═══════════════════════════════════════════════════════════"
log "  Daily news pipeline · date=$DATE · commit=${COMMIT_FLAG:-NO}"
log "  Log: $LOG"
log "═══════════════════════════════════════════════════════════"

step "0/7 fetch feeds"   "$PY" "$HERE/0_fetch_feeds.py" --date "$DATE"
step "1/7 curate"        "$PY" "$HERE/1_curate.py" --date "$DATE" $COMMIT_FLAG
[ -n "$COMMIT_FLAG" ] || { log "(dry-run mode — stopping after step 1; re-run with --commit to continue)"; exit 0; }
# Two editions from one curate pass (ENGLISH_NEWS_EDITION_SPEC.md):
#   ko — Korean-audio pack for English speakers (news_latest)
#   en — English-audio pack for Korean learners (news_en_latest)
for ED in ko en; do
    step "2/7 generate script ($ED)" "$PY" "$HERE/2_generate_script.py" --date "$DATE" --edition "$ED" $COMMIT_FLAG
    step "2b/7 translate easy ($ED)" "$PY" "$HERE/2b_translate_easy.py" --date "$DATE" --edition "$ED"
    step "3/7 synthesize ($ED)"      "$PY" "$HERE/3_synthesize.py" --date "$DATE" --edition "$ED" $COMMIT_FLAG
    step "4/7 assemble bundle ($ED)" "$PY" "$HERE/4_assemble_bundle.py" --date "$DATE" --edition "$ED"
    step "5/7 publish s3 ($ED)"      "$PY" "$HERE/5_publish_s3.py" --date "$DATE" --edition "$ED" $COMMIT_FLAG
done
step "6/7 deploy web (ko)" "$PY" "$HERE/6_deploy_news_page.py" --date "$DATE" $COMMIT_FLAG

# Aggregate per-step cost reports into a single cost_history entry
python3 -c "
from pathlib import Path
from cost_tracker import finalize_run
out = finalize_run(Path('$WORK_DIR'), Path('$HERE/cache'), '$DATE')
print(f'💰 Cost ledger: {out}')
" 2>&1 | tee -a "$LOG"

log "🎉 Daily pipeline complete for $DATE"
log "   Manifests: $WORK_DIR/bundle.json + bundle_en.json"
log "   QR:        $WORK_DIR/qr.png + qr_en.png"
log "   Web:      https://sixwandsstudios.com/news/$DATE/"
