

export PYTHONPATH=`pwd`

export ANTHROPIC_API_KEY=[REDACTED-ANTHROPIC-KEY]
export OPENAI_API_KEY=[REDACTED-OPENAI-KEY]
export OPENAI_API_MODEL=gpt-5

DATABASE_URL=postgresql://planning_user:[REDACTED-PASSWORD]@localhost:5433/planning_db


function step1() {
    PYTHONPATH=`pwd` python bundle_pipeline/scripts/init_bundle.py \
    --bundle-id akc-travel-korean-01 \
    --source-s3 s3://placeholder --language-code ko-KR --bundle-title "AKC Travel Korean" \
    --author "AKC" --work-root ./work
}

function copy_files() {
    cp akc_audio/*.mp3 work/akc-travel-korean-01/audio/
}

function transcribe() {
    python bundle_pipeline/scripts/transcribe_whisper.py --bundle-id akc-travel-korean-01 --work-root ./work
}

function curate() {
    python bundle_pipeline/scripts/curate_llm.py --bundle-id akc-travel-korean-01 --work-root ./work
}

function bundle(){
    python bundle_pipeline/scripts/assemble_manifest.py \
    --bundle-id akc-travel-korean-01 \
    --work-root ./work
}

function publish(){
 python bundle_pipeline/scripts/publish_bundle.py \
    --bundle-id akc-travel-korean-01 \
    --work-root ./work
}
#copy_files
#transcribe
#curate
#bundle
publish


