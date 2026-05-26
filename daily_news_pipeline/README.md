# Daily News Pipeline

Generates a daily Korean-language news listening pack from U.S. news sources and
publishes it for English-speaking Korean learners.

## Audience and shape

- **Target listener**: English speakers learning Korean who want to keep up with
  U.S. news (not Korean domestic news) while practicing comprehension.
- **Daily output**: one Pack containing 3-5 Tracks (one per chosen story).
  Each Track has 3 PracticeSets:
  1. **Beginner (with English)** — full bilingual narration: vocab, examples,
     expressions, full Korean summary, full English summary.
  2. **Korean phrase loops** — Korean-only stretches, broken into short clips
     for pronunciation drill (vocab words, example sentences, expressions,
     summary sentences).
  3. **Full Korean summary** — the summary as one continuous clip.

## Section structure per story

1. **어휘 / Vocabulary** — 5 advanced Korean words pulled from the translation
2. **예문 / Example sentences** — 2 sample phrases per vocab word (10 total)
3. **표현 / Key expressions** — 2 useful expressions from the news story
4. **뉴스 / News** — Korean summary (3 sentences) followed by English summary (Beginner set only)

Voices: English male teacher (Voice A) + Korean female narrator (Voice B), both
via ElevenLabs `eleven_multilingual_v2`.

## Pipeline (7 steps + cron entrypoint)

```
0_fetch_feeds.py        → pull RSS from 5 hard-news + 4 feature sources
                          → work/<date>/feeds.json

1_curate.py             → Claude picks 3 hard + 1-2 features, fetches bodies
                          via trafilatura
                          → work/<date>/chosen.json (3-5 articles w/ body text)

2_generate_script.py    → Claude builds the 4-section script per story
                          → work/<date>/script.json (turns + clip definitions)

3_synthesize_elevenlabs.py → per-turn TTS, concat to one mp3 per story
                          → work/<date>/audio/<story_id>.mp3
                          → work/<date>/audio/<story_id>.timings.json

4_assemble_bundle.py    → compute clip startMs/endMs from turn durations,
                          build Pack/Track/PracticeSet/Clip JSON
                          → work/<date>/bundle.json

5_publish_s3.py         → upload audio + bundle.json to s3://turned.rip/lmaudio/
                          generate QR PNG pointing at the CloudFront manifest URL
                          → work/<date>/qr.png

6_deploy_news_page.py   → render today's HTML page to
                          ~/Desktop/sixwandsstudiosllc/sixwands.com/news/<date>/
                          and update rolling /news/index.html archive landing
                          → cp-only S3 upload, NEVER --delete

run_daily.sh            → cron entrypoint: 0→6 in sequence, logs to work/<date>/run.log
```

## Cron timing

8am ET run, pack lands ~9am ET. macOS launchd plist included as `daily_news.plist`.

## Cost model (per day)

- Claude curation: ~$0.05
- Claude script generation: ~$0.20 (5 stories × structured generation)
- ElevenLabs TTS: ~$0.13 (~10 min audio total)
- S3 PUT + CloudFront: ~$0.001
- **Total: ~$0.40/day, ~$12/month**

## Safety gates

- All API-spending steps default to dry-run; require `--commit` to actually spend
- Hard character cap on TTS (10,000 chars/run by default)
- S3 deploy: **cp-only**, never `aws s3 sync --delete`, never `aws s3 rm`
- Pre-flight check before web deploy confirms key top-level files still exist on
  the website bucket
- The local source-of-truth site under `~/Desktop/sixwandsstudiosllc/sixwands.com/`
  is git-versioned, so every deploy creates a recovery commit before S3 push

## Source feeds

**Hard news** (5):
- NPR Top Stories (`https://feeds.npr.org/1001/rss.xml`)
- Reuters US wire (`https://www.reuters.com/world/us/`)
- AP Top News (`https://rsshub.app/apnews/topics/apf-topnews`)
- NYT Home Page (`https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml`)
- BBC US/Canada (`http://feeds.bbci.co.uk/news/world/us_and_canada/rss.xml`)

**Features** (4, genre-tagged):
- Reuters Technology
- Reuters Science
- ESPN top headlines
- NPR Arts & Entertainment

## File layout

```
daily_news_pipeline/
├── README.md                       ← this file
├── requirements.txt
├── 0_fetch_feeds.py
├── 1_curate.py
├── 2_generate_script.py
├── 3_synthesize_elevenlabs.py
├── 4_assemble_bundle.py
├── 5_publish_s3.py
├── 6_deploy_news_page.py
├── run_daily.sh
├── feeds.yaml                      ← feed sources config
├── voices.yaml                     ← ElevenLabs voice ids
└── work/
    └── <YYYY-MM-DD>/
        ├── feeds.json
        ├── chosen.json
        ├── script.json
        ├── audio/
        ├── bundle.json
        ├── qr.png
        └── run.log
```
