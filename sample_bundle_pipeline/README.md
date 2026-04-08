# Sample Bundle Pipeline

End-to-end flow for generating Language Mirror sample bundles from a topic
description, using LLM-generated narration and AWS Polly TTS, then publishing
either as a QR-shareable bundle or embedding inside the app.

## The 4 steps

```
┌────────────────────┐    ┌─────────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ 1. generate_script │ →  │ 2. synthesize_audio │ →  │ 3. make_qr_pack  │ →  │ 4. embed_in_app  │
│   topic → script   │    │   script → audio    │    │  audio → S3 + QR │    │ bundle → in-app  │
└────────────────────┘    └─────────────────────┘    └──────────────────┘    └──────────────────┘
                                                              │
                                                              ▼
                                                       (QA via TestFlight scan)
```

Each step is **independent** and **resumable**. Step outputs land in
`samples/<bundle_id>/` so you can re-run any step without re-doing earlier ones.

Step 3 is *not* coupled to step 1: it always reads from audio files on disk,
so manually-recorded audio works the same way as Polly-generated audio.

## Safety: human in the loop for AWS

Steps 2 and 3 can spend AWS money (Polly synthesis, S3 publish). They both
**default to dry-run mode** and require an explicit `--commit` flag to actually
hit AWS. Each shows a cost estimate before any spend.

## Directory layout

```
sample_bundle_pipeline/
├── README.md                  ← this file
├── 1_generate_script.py
├── 2_synthesize_audio.py
├── 3_make_qr_pack.sh
├── 4_embed_in_app.py
└── samples/
    └── <bundle_id>/
        ├── topic.md           ← you write this (or pass as CLI arg)
        ├── script.json        ← step 1 output
        └── audio/             ← step 2 output (per-turn mp3s + concatenated tracks)
```

After step 3, work artifacts land in the existing `work/<bundle_id>/` folder
under the bundle_pipeline. After step 4, the app's
`LanguageMirror/.../Resources/embedded_bundles/<bundle_id>/` folder gets the
embedded copy.

## Usage example

```bash
# 1. Generate a Korean conversation script about ordering coffee
python sample_bundle_pipeline/1_generate_script.py \
    --bundle-id starter_coffee \
    --topic "Two friends order coffee at a Seoul cafe" \
    --language ko-KR \
    --duration-seconds 60 \
    --num-speakers 2

# 2. Synthesize with Polly (dry-run shows cost; --commit actually spends)
python sample_bundle_pipeline/2_synthesize_audio.py \
    --bundle-id starter_coffee
# review the cost estimate, then:
python sample_bundle_pipeline/2_synthesize_audio.py \
    --bundle-id starter_coffee --commit

# 3. Run through the existing bundle pipeline (transcribe → curate → S3 + QR)
./sample_bundle_pipeline/3_make_qr_pack.sh starter_coffee
# scan the QR code with TestFlight build to QA the result

# 4. Once happy, embed the bundle into the app
python sample_bundle_pipeline/4_embed_in_app.py \
    --bundle-id starter_coffee
# now re-archive the iOS app and ship
```

## Polly cost reference

- Neural voices: $4 per 1M characters (~$0.0004 per 100 chars)
- Generative voices: $16 per 1M characters
- A typical 60-second narration is ~600-800 chars = $0.003 per take

The synth script enforces a hard cap of 10,000 characters per run by default;
override with `--max-chars` if you really mean it.

## Voice picks

Korean (neural):
- `Seoyeon` — female (default)

English (neural):
- `Joanna` — US female
- `Matthew` — US male
- `Amy` — UK female
- `Brian` — UK male

For multi-speaker scripts the `voice` field per turn picks which Polly voice
to use. If unspecified, the script alternates between two defaults for the
selected language.
