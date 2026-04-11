"""
Local Prefect worker that polls the pack_editor database for pending
transcription jobs, downloads audio from S3, runs Whisper + LLM curation,
and writes clips/transcript_spans back to the database.

Usage:
    cd pack_editor
    python -m worker.transcribe_flow          # run once
    python -m worker.transcribe_flow --loop   # poll every 5 minutes
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
import tempfile
import time
from pathlib import Path

# Ensure the pack_editor root is importable and bundle_pipeline is reachable
PACK_EDITOR_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = PACK_EDITOR_ROOT.parent
sys.path.insert(0, str(PACK_EDITOR_ROOT))
sys.path.insert(0, str(REPO_ROOT))

from dotenv import load_dotenv
load_dotenv(PACK_EDITOR_ROOT / ".env")

import boto3
from psycopg_pool import ConnectionPool

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [worker] %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("transcribe_worker")

# ── Config from env ────────────────────────────────────────────���───────

DATABASE_URL = os.environ.get("DATABASE_URL", "")
S3_BUCKET = os.environ.get("S3_BUCKET_NAME", "")
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "base")
GPT_MODEL = os.environ.get("GPT_MODEL", "gpt-4o-mini")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL_SECONDS", "300"))


def get_pool() -> ConnectionPool:
    return ConnectionPool(conninfo=DATABASE_URL, min_size=1, max_size=2, open=True)


# ── DB helpers (standalone, no app import) ─────────────────────────────

def fetch_pending_jobs(pool: ConnectionPool) -> list[dict]:
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT j.id, j.track_id, j.job_type,
                       t.s3_key, t.filename, t.duration_ms, t.language_code
                FROM job j
                JOIN track t ON t.id = j.track_id
                WHERE j.status = 'pending'
                ORDER BY j.created_at
                LIMIT 5;
                """
            )
            rows = cur.fetchall()
            return [
                {
                    "job_id": str(r[0]), "track_id": str(r[1]), "job_type": r[2],
                    "s3_key": r[3], "filename": r[4], "duration_ms": r[5], "language_code": r[6],
                }
                for r in rows
            ]


def set_job_status(pool: ConnectionPool, job_id: str, status: str, error: str | None = None):
    with pool.connection() as conn:
        with conn.cursor() as cur:
            if status in ("done", "failed"):
                cur.execute(
                    "UPDATE job SET status=%s, error_message=%s, completed_at=now() WHERE id=%s",
                    (status, error, job_id),
                )
            else:
                cur.execute("UPDATE job SET status=%s WHERE id=%s", (status, job_id))
            conn.commit()


def clear_track_data(pool: ConnectionPool, track_id: str):
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM clip WHERE track_id=%s", (track_id,))
            cur.execute("DELETE FROM transcript_span WHERE track_id=%s", (track_id,))
            cur.execute("DELETE FROM practice_set WHERE track_id=%s", (track_id,))
            conn.commit()


def insert_results(pool: ConnectionPool, track_id: str, curated: dict, language_code: str | None):
    with pool.connection() as conn:
        with conn.cursor() as cur:
            # Create practice set
            cur.execute(
                "INSERT INTO practice_set (track_id, title, display_order) VALUES (%s, 'Practice Set', 0) RETURNING id",
                (track_id,),
            )
            ps_id = str(cur.fetchone()[0])

            # Insert clips
            for i, c in enumerate(curated.get("clips", [])):
                cur.execute(
                    """
                    INSERT INTO clip (track_id, practice_set_id, start_ms, end_ms, kind, title, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (track_id, ps_id, c["startMs"], c["endMs"], c.get("kind", "drill"), c.get("title", ""), i),
                )

            # Insert transcript spans
            for i, s in enumerate(curated.get("transcripts", [])):
                cur.execute(
                    """
                    INSERT INTO transcript_span (track_id, start_ms, end_ms, text, speaker, language_code, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (track_id, s["startMs"], s["endMs"], s["text"], s.get("speaker", ""), language_code, i),
                )
            conn.commit()


# ── Main processing ────────────────────────────────────────────────────

def process_job(pool: ConnectionPool, job: dict):
    job_id = job["job_id"]
    track_id = job["track_id"]
    log.info("Processing job %s for track %s (%s)", job_id, track_id, job["filename"])

    set_job_status(pool, job_id, "running")

    try:
        # 1. Download audio from S3
        s3 = boto3.client("s3")
        with tempfile.NamedTemporaryFile(suffix=Path(job["filename"]).suffix, delete=False) as tmp:
            log.info("  Downloading s3://%s/%s", S3_BUCKET, job["s3_key"])
            s3.download_file(S3_BUCKET, job["s3_key"], tmp.name)
            audio_path = Path(tmp.name)

        try:
            # 2. Run Whisper
            from bundle_pipeline.whisper_tools import transcribe_with_whisper, extract_segments_for_llm
            log.info("  Running Whisper (model=%s)...", WHISPER_MODEL)
            whisper_result = transcribe_with_whisper(audio_path, WHISPER_MODEL, job["language_code"])
            segments = extract_segments_for_llm(whisper_result)
            log.info("  Whisper produced %d segments", len(segments))

            # 3. Run LLM curation
            from bundle_pipeline.openai_tools import build_curation_prompt, curate_with_openai
            duration_ms = job["duration_ms"] or 0
            prompt = build_curation_prompt(segments, duration_ms, job["language_code"])
            log.info("  Running LLM curation (model=%s)...", GPT_MODEL)
            curated = curate_with_openai(GPT_MODEL, prompt)
            log.info("  LLM produced %d clips, %d transcripts",
                     len(curated.get("clips", [])), len(curated.get("transcripts", [])))

            # 4. Clear old data and insert new
            clear_track_data(pool, track_id)
            insert_results(pool, track_id, curated, job["language_code"])

            set_job_status(pool, job_id, "done")
            log.info("  Job %s completed successfully", job_id)

        finally:
            audio_path.unlink(missing_ok=True)

    except Exception as e:
        log.error("  Job %s failed: %s", job_id, e, exc_info=True)
        set_job_status(pool, job_id, "failed", str(e))


def run_once(pool: ConnectionPool) -> int:
    jobs = fetch_pending_jobs(pool)
    if not jobs:
        log.info("No pending jobs")
        return 0
    log.info("Found %d pending job(s)", len(jobs))
    for job in jobs:
        process_job(pool, job)
    return len(jobs)


def main():
    parser = argparse.ArgumentParser(description="Transcription worker")
    parser.add_argument("--loop", action="store_true", help="Poll continuously")
    args = parser.parse_args()

    if not DATABASE_URL:
        log.error("DATABASE_URL not set")
        sys.exit(1)

    pool = get_pool()
    log.info("Worker started (whisper=%s, gpt=%s)", WHISPER_MODEL, GPT_MODEL)

    if args.loop:
        log.info("Polling every %ds", POLL_INTERVAL)
        while True:
            try:
                run_once(pool)
            except Exception as e:
                log.error("Poll cycle error: %s", e, exc_info=True)
            time.sleep(POLL_INTERVAL)
    else:
        run_once(pool)


if __name__ == "__main__":
    main()
