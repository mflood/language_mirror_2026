# bundle_pipeline — audio-first pack producer

Turns existing audio (an S3 prefix or local files) into a Language Mirror
pack: download → Whisper transcribe → LLM curate (clip boundaries + titles)
→ assemble bundle.json → publish. This built the app's five embedded starter
packs and the AKC travel packs (`make_akc_bundle*.sh` at the repo root).

**Shared-infrastructure role retired (2026-07-06):** the iOS bundle schema
now comes from langpack `bundler.models`, and publishing goes through the
langpack `publisher` (destination `lmaudio`, with clobber gate / `--redeploy`
/ post-flight verify / CloudFront invalidation). The former local copies
(`models.py`, `qrcode_tools.py`, `s3io.upload_files`, `PublishConfig` +
`bundle_publish_config.yaml`) are gone; `s3io.py` keeps only the download
helpers.

Still local (the unique producer pieces):
- `whisper_tools.py` / `openai_tools.py` — transcription + curation
  (also imported by pack_editor's worker; keep interfaces stable)
- `scripts/` — init → download → transcribe → curate → assemble → publish
- `translate_bundle.py` — DEPRECATED backfill tool (native translations now)

Workflow: see `make_akc_bundle.sh`. Runs in the six_wands venv (langpack
packages installed editable).
