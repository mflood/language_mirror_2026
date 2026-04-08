#!/usr/bin/env bash
#
# Step 3: Run a folder of audio files through the existing bundle_pipeline:
#   init → copy → transcribe (whisper) → curate (LLM) → assemble manifest
#   → publish to S3 + generate QR code.
#
# This is a parameterized version of make_akc_bundle_4.sh. It expects:
#   - A folder of source .mp3/.m4a/.wav files
#   - OPENAI_API_KEY exported (curation step needs it)
#   - AWS credentials configured (publish step needs them)
#   - Python venv at python_scripts/venv (or activate one yourself before running)
#
# Safety: this script makes paid API calls (OpenAI for curation, AWS S3 for
# publish). It does NOT prompt for confirmation — invoke deliberately, or
# pass --dry-run to print the steps without executing them.
#
# Usage:
#   ./sample_bundle_pipeline/3_make_qr_pack.sh <bundle-id> <source-audio-dir> [options]
#
#   Options:
#     --dry-run                 Print the planned steps and exit
#     --language-code <code>    Language code (default: ko-KR)
#     --bundle-title <title>    Display title (default: same as bundle-id)
#     --author <name>           Bundle author (default: "Six Wands Studios")
#     --skip-init               Don't re-init (assumes work dir already exists)
#
# After this completes successfully:
#   - work/<bundle-id>/bundle.json holds the manifest
#   - work/<bundle-id>/qr.png is the QR code (open it and scan with TestFlight)
#   - The bundle is published at https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/<bundle-id>/bundle.json
#
# Then proceed to step 4 to embed the bundle into the app, or just share the QR
# code with testers.

set -e

DRY_RUN=0
LANGUAGE_CODE="ko-KR"
BUNDLE_TITLE=""
AUTHOR="Six Wands Studios"
SKIP_INIT=0

# Positional args
if [ $# -lt 2 ]; then
    echo "Usage: $0 <bundle-id> <source-audio-dir> [options]" >&2
    echo "Run with --help for details" >&2
    exit 1
fi

BUNDLE_ID="$1"
SOURCE_AUDIO_DIR="$2"
shift 2

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --language-code)
            LANGUAGE_CODE="$2"
            shift 2
            ;;
        --bundle-title)
            BUNDLE_TITLE="$2"
            shift 2
            ;;
        --author)
            AUTHOR="$2"
            shift 2
            ;;
        --skip-init)
            SKIP_INIT=1
            shift
            ;;
        --help|-h)
            head -n 35 "$0" | tail -n 32
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$BUNDLE_TITLE" ]; then
    BUNDLE_TITLE="$BUNDLE_ID"
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
export PYTHONPATH="$REPO_ROOT"

# Sanity checks
if [ ! -d "$SOURCE_AUDIO_DIR" ]; then
    echo "❌ Source audio directory does not exist: $SOURCE_AUDIO_DIR" >&2
    exit 1
fi

AUDIO_COUNT=$(find "$SOURCE_AUDIO_DIR" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.wav" \) | wc -l | tr -d ' ')
if [ "$AUDIO_COUNT" = "0" ]; then
    echo "❌ No audio files found in: $SOURCE_AUDIO_DIR" >&2
    exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "❌ OPENAI_API_KEY is not set. Curation step needs it." >&2
    exit 1
fi

# Show plan
echo "═══════════════════════════════════════════════════════════"
echo "  Bundle ID:    $BUNDLE_ID"
echo "  Source:       $SOURCE_AUDIO_DIR ($AUDIO_COUNT audio files)"
echo "  Language:     $LANGUAGE_CODE"
echo "  Title:        $BUNDLE_TITLE"
echo "  Author:       $AUTHOR"
echo "  Work root:    $REPO_ROOT/work"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Pipeline:"
[ $SKIP_INIT -eq 0 ] && echo "  1. init_bundle.py (creates work/$BUNDLE_ID/)"
echo "  2. copy audio files to work/$BUNDLE_ID/audio/"
echo "  3. transcribe_whisper.py     [LOCAL whisper, free]"
echo "  4. curate_llm.py             [OpenAI API call, ~\$0.01 per file]"
echo "  5. assemble_manifest.py      [free, local]"
echo "  6. publish_bundle.py         [AWS S3 PUT, ~\$0.005 per upload]"
echo

if [ $DRY_RUN -eq 1 ]; then
    echo "--- DRY RUN — no commands will be executed ---"
    exit 0
fi

run() {
    echo "▶ $*"
    "$@"
}

if [ $SKIP_INIT -eq 0 ]; then
    run python bundle_pipeline/scripts/init_bundle.py \
        --bundle-id "$BUNDLE_ID" \
        --source-s3 s3://placeholder \
        --language-code "$LANGUAGE_CODE" \
        --bundle-title "$BUNDLE_TITLE" \
        --author "$AUTHOR" \
        --work-root ./work
fi

run cp "$SOURCE_AUDIO_DIR"/*.mp3 "work/$BUNDLE_ID/audio/" 2>/dev/null || true
run cp "$SOURCE_AUDIO_DIR"/*.m4a "work/$BUNDLE_ID/audio/" 2>/dev/null || true
run cp "$SOURCE_AUDIO_DIR"/*.wav "work/$BUNDLE_ID/audio/" 2>/dev/null || true

run python bundle_pipeline/scripts/transcribe_whisper.py --bundle-id "$BUNDLE_ID" --work-root ./work
run python bundle_pipeline/scripts/curate_llm.py        --bundle-id "$BUNDLE_ID" --work-root ./work --force
run python bundle_pipeline/scripts/assemble_manifest.py --bundle-id "$BUNDLE_ID" --work-root ./work
run python bundle_pipeline/scripts/publish_bundle.py    --bundle-id "$BUNDLE_ID" --work-root ./work

echo
echo "🎉 Done. Next steps:"
echo "  - Open work/$BUNDLE_ID/qr.png and scan with TestFlight to verify"
echo "  - When happy, run: python sample_bundle_pipeline/4_embed_in_app.py --bundle-id $BUNDLE_ID"
