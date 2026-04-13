
set -e

export PYTHONPATH=`pwd`

export ANTHROPIC_API_KEY=[REDACTED-ANTHROPIC-KEY]
export OPENAI_API_KEY=[REDACTED-OPENAI-KEY]
export OPENAI_API_MODEL=gpt-5

DATABASE_URL=postgresql://planning_user:[REDACTED-PASSWORD]@localhost:5433/planning_db

BUNDLE_ID="akc-travel-korean-pack-4"
SOURCE_AUDIO_DIR="./akc_audio_pack_4"

function init_bundle() {
    PYTHONPATH=`pwd` python bundle_pipeline/scripts/init_bundle.py \
    --bundle-id "$BUNDLE_ID" \
    --source-s3 s3://placeholder --language-code ko-KR --bundle-title "AKC Travel Korean" \
    --author "AKC" --work-root ./work
}

function copy_files() {
    cp $SOURCE_AUDIO_DIR/*.mp3 work/$BUNDLE_ID/audio/
}

function transcribe() {
    python bundle_pipeline/scripts/transcribe_whisper.py --bundle-id "$BUNDLE_ID" --work-root ./work
}

function curate() {
    python bundle_pipeline/scripts/curate_llm.py --bundle-id "$BUNDLE_ID" --work-root ./work --force
}

function bundle(){
    python bundle_pipeline/scripts/assemble_manifest.py \
    --bundle-id "$BUNDLE_ID" \
    --work-root ./work
}

function publish(){
 python bundle_pipeline/scripts/publish_bundle.py \
    --bundle-id "$BUNDLE_ID" \
    --work-root ./work
}

init_bundle
copy_files
transcribe
curate
bundle
publish


