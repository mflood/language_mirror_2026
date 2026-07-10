# ElevenLabs starter-pack workflow

End-to-end flow for generating a Language Mirror starter pack using
ElevenLabs TTS instead of AWS Polly. Replaces step 2 of the Polly pipeline;
steps 1, 3, and 4 are unchanged.

Use this when you want:
- A natural Korean **male** voice (Polly doesn't have one)
- More expressive emotion / prosody than Polly neural produces
- Multilingual voices that handle Korean and English in one pack

---

## Pipeline overview

```
┌────────────────────┐    ┌──────────────────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ 1. generate_script │ →  │ 2_el. synthesize_elevenlabs  │ →  │ 3. make_qr_pack  │ →  │ 4. embed_in_app  │
│   (unchanged)      │    │   script → audio (NEW)       │    │   (unchanged)    │    │   (unchanged)    │
└────────────────────┘    └──────────────────────────────┘    └──────────────────┘    └──────────────────┘
```

The new step 2 (`2_synthesize_audio_elevenlabs.py`, see "Implementation
checklist" below) writes its output to the same `samples/<bundle_id>/audio/`
location as the Polly synth, so steps 3 and 4 don't care which TTS produced
the audio.

---

## One-time setup

### 1. ElevenLabs account & API key

1. Create an account at https://elevenlabs.io.
2. Tier choice for starter packs:
   - **Free** (10K chars/mo) — fine for trying one or two packs.
   - **Creator $22/mo** (100K chars/mo) — required for **commercial use**;
     this is the minimum tier we should be on if a pack ships in the App
     Store .ipa or our CDN. Read their commercial-use clause carefully.
3. Profile → API Keys → create a key, store it locally:

   ```bash
   # Add to ~/.zshrc (or wherever you keep the other API keys)
   export ELEVENLABS_API_KEY="sk_..."
   ```

### 2. Pick voice ids from the Voice Library

ElevenLabs voices are model-agnostic — pick any voice id and pair it with
the `eleven_multilingual_v2` model and it will speak the language in
`script.json`. Browse https://elevenlabs.io/app/voice-library and copy the
voice id (looks like `21m00Tcm4TlvDq8ikWAM`).

Voice picks worth trying for our content:

| Use case          | Voice name in library | Notes |
|-------------------|-----------------------|-------|
| Korean female (warm)  | "Bella" or "Rachel"      | Multilingual v2 handles Korean fluently |
| Korean male (warm)    | "Adam" or "Antoni"       | Fixes Polly's gender-only-female problem |
| Korean male (gravelly)| "Arnold"                 | Good for older-narrator monologues |
| English female (calm) | "Sarah"                  | For Korean-learner-of-English packs |
| English male (clear)  | "Daniel" / "Brian"       | Slow, deliberate — good for pronunciation drills |

You will need the actual voice **id** (not the name) from the library page.
Save the ones you settle on at the top of the new synth script as constants
so we get consistent voices across packs.

### 3. Python deps

```bash
pip install elevenlabs   # the official SDK
# pydub + ffmpeg are already required by the Polly path; reuse them
```

---

## Step-by-step: generating one pack

Example: a beginner Korean dialogue with one female + one male voice.

### Step 1 — Generate the script

Same as the Polly path. The `voice` field in `script.json` will contain
Polly voice names (Seoyeon / Jihye); the new ElevenLabs synth script
**ignores** these and remaps by speaker letter (A / B). No script changes
needed.

```bash
python sample_bundle_pipeline/1_generate_script.py \
    --bundle-id starter_seoul_market \
    --topic "Two friends bargain at a Namdaemun market stall" \
    --language ko-KR \
    --duration-seconds 60 \
    --num-speakers 2 \
    --commit
```

Output: `sample_bundle_pipeline/samples/starter_seoul_market/script.json`

### Step 2 — Synthesize with ElevenLabs (NEW)

```bash
# Dry run (no API spend, prints plan + cost estimate)
python sample_bundle_pipeline/2_synthesize_audio_elevenlabs.py \
    --bundle-id starter_seoul_market \
    --voice-a <FEMALE_VOICE_ID> \
    --voice-b <MALE_VOICE_ID>

# Review estimate, then commit:
python sample_bundle_pipeline/2_synthesize_audio_elevenlabs.py \
    --bundle-id starter_seoul_market \
    --voice-a <FEMALE_VOICE_ID> \
    --voice-b <MALE_VOICE_ID> \
    --commit
```

Output (same shape as Polly path so steps 3/4 work unchanged):
```
samples/starter_seoul_market/audio/
  ├── track_001.mp3            ← concatenated final track
  ├── script.timed.json        ← per-turn timings
  └── turns/
      ├── turn_000.mp3
      ├── turn_001.mp3
      └── ...
```

### QA gate — listen before continuing

```bash
afplay sample_bundle_pipeline/samples/starter_seoul_market/audio/track_001.mp3
```

If the result sounds wrong (mispronounced Korean, wrong emotion, weird
pauses), iterate in this order before spending more money downstream:

1. Re-run step 2 with different `--voice-a`/`--voice-b` ids — voices vary
   wildly in how they handle Korean. Some library voices were trained on
   English-only data and produce a heavy English accent in Korean.
2. Tweak the script.json text directly (add/remove punctuation; ElevenLabs
   honors commas, periods, ellipses, em-dashes for prosody).
3. Try the `eleven_turbo_v2_5` model for cheaper iteration during voice
   selection, then re-render with `eleven_multilingual_v2` for the final.

### Step 3 — Make QR pack (unchanged)

```bash
./sample_bundle_pipeline/3_make_qr_pack.sh starter_seoul_market \
    sample_bundle_pipeline/samples/starter_seoul_market/audio
```

This transcribes via Whisper, curates clip boundaries via OpenAI, publishes
to S3, and emits a QR code at `work/starter_seoul_market/qr.png`.

### Step 4 — Embed in app (unchanged)

```bash
python sample_bundle_pipeline/4_embed_in_app.py \
    --bundle-id starter_seoul_market
```

Then add an entry to
`LanguageMirror/.../Resources/featured_catalog.json` so the pack appears in
the Featured Packs UI:

```json
{
  "id": "starter_seoul_market",
  "title": "Namdaemun Market Bargaining",
  "subtitle": "Two friends haggle over price at a market stall",
  "languageCode": "ko-KR",
  "level": "beginner",
  "trackCount": 1,
  "durationSeconds": 58,
  "author": "Six Wands Studios",
  "iconSymbol": "bag.fill",
  "accentColor": "#D4A24C",
  "source": { "kind": "embedded", "bundleId": "starter_seoul_market" }
}
```

Re-archive the iOS app and ship.

---

## Cost model

ElevenLabs charges per character of input. Multilingual v2 at the Creator
tier works out to roughly **10× the cost per character of Polly neural**:

| Synth path              | Per 60s pack (~700 chars) | Per 100 packs |
|-------------------------|---------------------------|---------------|
| Polly neural (today)    | ~$0.003                   | ~$0.30        |
| Polly generative        | ~$0.011                   | ~$1.10        |
| ElevenLabs Multilingual v2 | ~$0.13                | ~$13          |

The character cost is irrelevant for our scale (we ship single-digit
starter packs, not a continuous content treadmill). The real cost is the
$22/mo Creator subscription — only pay for it when actively rendering.

The new synth script must:
- Default to **dry-run** (matches Polly script's safety pattern)
- Print a character count + estimated character debit before committing
- Enforce the same `DEFAULT_MAX_CHARS = 10_000` hard cap

---

## Implementation checklist for `2_synthesize_audio_elevenlabs.py`

This script does not exist yet — build it as a sibling to
`2_synthesize_audio.py`. Reuse as much as possible from the Polly version:

- [ ] CLI args mirror the Polly script: `--bundle-id`, `--script`,
      `--output-dir`, `--inter-turn-pause-ms`, `--max-chars`, `--commit`.
- [ ] **New args:** `--voice-a` (required), `--voice-b` (optional, defaults
      to `--voice-a`), `--model` (default `eleven_multilingual_v2`),
      `--stability` (default 0.5), `--similarity-boost` (default 0.75).
- [ ] Map `turn["speaker"]` letter → voice id (ignore `turn["voice"]`,
      which holds Polly voice names from step 1).
- [ ] API call: `from elevenlabs import ElevenLabs` →
      `client.text_to_speech.convert(text=..., voice_id=..., model_id=...,
      output_format="mp3_44100_128")`. Stream to disk.
- [ ] Concatenation + sidecar `script.timed.json` writing — copy verbatim
      from the Polly script's pydub block (`synth_with_polly` lines
      146–184). Same output shape so step 3 doesn't notice the difference.
- [ ] Cost estimate: print character total, note "ElevenLabs character
      debit" rather than dollar cost (since dollar cost depends on tier).
- [ ] Same `--commit` gate, same dry-run-by-default behavior, same
      `>$1.00` confirmation prompt adapted for "more than 5,000 chars".
- [ ] On HTTP 429 (rate limit) back off and retry with exponential delay;
      Polly didn't need this but ElevenLabs throttles aggressively.

When this exists, update the top-level `sample_bundle_pipeline/README.md`
to point at this doc as an alternative step 2 path.

---

## Choosing between Polly and ElevenLabs

| Need                                              | Use         |
|---------------------------------------------------|-------------|
| Korean dialogue with male + female voices         | ElevenLabs  |
| English pronunciation packs for Korean learners   | ElevenLabs  |
| Cheap iteration during script writing             | Polly neural|
| Bulk-generating many packs                        | Polly neural|
| Premium "showcase" pack you want to look polished | ElevenLabs  |
| Anything with strong emotion (surprise, sadness)  | ElevenLabs  |
