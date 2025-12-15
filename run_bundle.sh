#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./run_bundle.sh --bundle-id <id> --source-s3 <s3://.../> --language-code <ko-KR|en-US|zh-CN|es-ES> [--bundle-title "..."] [--pack-title "..."] [--work-root work]

Pipeline:
  init -> download -> transcribe -> curate -> assemble -> publish
EOF
}

BUNDLE_ID=""
SOURCE_S3=""
LANGUAGE_CODE=""
BUNDLE_TITLE=""
PACK_TITLE=""
WORK_ROOT="work"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id) BUNDLE_ID="$2"; shift 2 ;;
    --source-s3) SOURCE_S3="$2"; shift 2 ;;
    --language-code) LANGUAGE_CODE="$2"; shift 2 ;;
    --bundle-title) BUNDLE_TITLE="$2"; shift 2 ;;
    --pack-title) PACK_TITLE="$2"; shift 2 ;;
    --work-root) WORK_ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "$BUNDLE_ID" || -z "$SOURCE_S3" || -z "$LANGUAGE_CODE" ]]; then
  usage
  exit 2
fi

INIT_ARGS=(--bundle-id "$BUNDLE_ID" --source-s3 "$SOURCE_S3" --language-code "$LANGUAGE_CODE" --work-root "$WORK_ROOT")
if [[ -n "$BUNDLE_TITLE" ]]; then INIT_ARGS+=(--bundle-title "$BUNDLE_TITLE"); fi
if [[ -n "$PACK_TITLE" ]]; then INIT_ARGS+=(--pack-title "$PACK_TITLE"); fi

python3 bundle_pipeline/scripts/init_bundle.py "${INIT_ARGS[@]}"
python3 bundle_pipeline/scripts/download_audio.py --bundle-id "$BUNDLE_ID" --work-root "$WORK_ROOT"
python3 bundle_pipeline/scripts/transcribe_whisper.py --bundle-id "$BUNDLE_ID" --work-root "$WORK_ROOT"
python3 bundle_pipeline/scripts/curate_llm.py --bundle-id "$BUNDLE_ID" --work-root "$WORK_ROOT"
python3 bundle_pipeline/scripts/assemble_manifest.py --bundle-id "$BUNDLE_ID" --work-root "$WORK_ROOT"
python3 bundle_pipeline/scripts/publish_bundle.py --bundle-id "$BUNDLE_ID" --work-root "$WORK_ROOT"


