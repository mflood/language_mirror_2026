#!/usr/bin/env python3
"""
Step 6: Render today's HTML news page into the local sixwands.com source tree,
git-commit, then cp-only sync the changed files to s3://sixwandsstudios.com/.

NEVER deletes anything. NEVER uses `aws s3 sync --delete` or `aws s3 rm`. Before
any upload, performs a pre-flight check that confirms the bucket root still
contains all known-good top-level files.

Output:
    ~/Desktop/sixwandsstudiosllc/sixwands.com/news/<date>/index.html
    ~/Desktop/sixwandsstudiosllc/sixwands.com/news/<date>/qr.png
    ~/Desktop/sixwandsstudiosllc/sixwands.com/news/index.html  (rolling archive)

Safety: defaults to dry-run. Pass --commit to git-commit + upload.

Usage:
    python 6_deploy_news_page.py [--date YYYY-MM-DD] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

SITE_REPO = Path.home() / "Desktop" / "sixwandsstudiosllc"
SITE_DIR = SITE_REPO / "sixwands.com"
S3_BUCKET = "sixwandsstudios.com"

# Known-good top-level keys that MUST exist before any deploy. If any is missing
# the deploy aborts — protects against accidental bucket-wipe scenarios.
PROTECTED_TOP_LEVEL = {
    "index.html",
    "error.html",
    "language-mirror.html",
    "language-mirror-privacy.html",
    "nardo.html",
    "nardo-privacy.html",
    "support.html",
    "style.css",
    "hero.png",
}

KO_MONTHS = ["", "1월", "2월", "3월", "4월", "5월", "6월", "7월", "8월", "9월", "10월", "11월", "12월"]
EN_MONTHS = ["", "January", "February", "March", "April", "May", "June",
             "July", "August", "September", "October", "November", "December"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Deploy today's news page to sixwandsstudios.com")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--commit", action="store_true", help="Git-commit + upload to S3.")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def render_date_titles(date: str) -> tuple[str, str]:
    y, m, d = date.split("-")
    yi, mi, di = int(y), int(m), int(d)
    ko = f"{yi}년 {KO_MONTHS[mi]} {di}일 뉴스"
    en = f"US News, {EN_MONTHS[mi]} {di}, {yi}"
    return ko, en


def render_day_page(date: str, manifest: dict, qr_filename: str) -> str:
    pack = manifest["packs"][0]
    title_ko = manifest["title"]
    _, title_en = render_date_titles(date)

    story_blocks = []
    for track in pack["tracks"]:
        story_blocks.append(f"""    <li>
      <span class="ko">{track['title']}</span>
    </li>""")
    stories_html = "\n".join(story_blocks)

    manifest_url = pack["tracks"][0]["url"].rsplit("/", 1)[0] + "/bundle.json"
    app_url = f"languagemirror://bundle?url={manifest_url.replace(':', '%3A').replace('/', '%2F')}"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{title_en} · Six Wands Studios</title>
  <link rel="stylesheet" href="/style.css">
  <style>
    .news-day {{ max-width: 640px; margin: 2rem auto; padding: 0 1rem; }}
    .news-day h1 {{ font-size: 1.6rem; }}
    .news-day .ko {{ font-size: 1.1rem; }}
    .qr {{ display: block; margin: 1.5rem auto; max-width: 280px; }}
    .news-day ul {{ padding-left: 1.2rem; }}
    .news-day li {{ margin: 0.4rem 0; }}
    .open-app {{ display: inline-block; margin-top: 1rem;
                 padding: 0.6rem 1rem; background: #2563eb; color: white;
                 border-radius: 8px; text-decoration: none; }}
    .archive-link {{ display: block; margin-top: 2rem; }}
  </style>
</head>
<body>
  <main class="news-day">
    <h1>{title_en}</h1>
    <h2 class="ko">{title_ko}</h2>
    <p>Scan with the Language Mirror app to load today's listening pack:</p>
    <img class="qr" src="qr.png" alt="QR code for today's news pack">
    <p><a class="open-app" href="{app_url}">Open in Language Mirror</a></p>
    <h3>Stories</h3>
    <ul>
{stories_html}
    </ul>
    <a class="archive-link" href="/news/">← Back to news archive</a>
  </main>
</body>
</html>
"""


def render_archive_page(news_root: Path) -> str:
    """List all date subdirs newest-first, link to each."""
    days = sorted(
        (p.name for p in news_root.iterdir() if p.is_dir() and len(p.name) == 10 and p.name[4] == "-"),
        reverse=True,
    )
    items = []
    for d in days[:60]:  # last 60 days max in the archive
        _, en = render_date_titles(d)
        items.append(f'    <li><a href="{d}/">{en}</a></li>')
    items_html = "\n".join(items) or "    <li><em>No days published yet.</em></li>"

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Daily Korean News · Six Wands Studios</title>
  <link rel="stylesheet" href="/style.css">
  <style>
    .archive {{ max-width: 640px; margin: 2rem auto; padding: 0 1rem; }}
    .archive h1 {{ font-size: 1.6rem; }}
    .archive ul {{ padding-left: 1.2rem; }}
    .archive li {{ margin: 0.4rem 0; }}
  </style>
</head>
<body>
  <main class="archive">
    <h1>Daily Korean News</h1>
    <p>A new Language Mirror pack every weekday — U.S. news translated to Korean
       for English speakers learning Korean.</p>
    <ul>
{items_html}
    </ul>
    <p><a href="/language-mirror.html">← About Language Mirror</a></p>
  </main>
</body>
</html>
"""


def preflight_bucket_check() -> None:
    """Abort if any PROTECTED_TOP_LEVEL key is missing from the bucket root."""
    print(f"🔍 Pre-flight: verifying integrity of s3://{S3_BUCKET}/")
    result = subprocess.run(
        ["aws", "s3api", "list-objects-v2", "--bucket", S3_BUCKET, "--delimiter", "/", "--prefix", ""],
        capture_output=True, text=True, check=True,
    )
    keys = {obj["Key"] for obj in (json.loads(result.stdout).get("Contents") or [])}
    missing = PROTECTED_TOP_LEVEL - keys
    if missing:
        raise SystemExit(
            f"❌ Pre-flight FAILED. Top-level keys missing from s3://{S3_BUCKET}/: {sorted(missing)}\n"
            f"   Refusing to deploy until the bucket integrity is restored."
        )
    print(f"   ✓ {len(PROTECTED_TOP_LEVEL)} protected keys all present:")
    for k in sorted(PROTECTED_TOP_LEVEL):
        print(f"     · s3://{S3_BUCKET}/{k}")


def check_destination_for_clobber(s3_keys: list[str]) -> dict[str, bool]:
    """For each target key, return whether it already exists on the bucket."""
    result = subprocess.run(
        ["aws", "s3api", "list-objects-v2", "--bucket", S3_BUCKET, "--prefix", "news/"],
        capture_output=True, text=True, check=True,
    )
    existing = set()
    if result.stdout.strip():
        existing = {obj["Key"] for obj in (json.loads(result.stdout).get("Contents") or [])}
    return {k: (k in existing) for k in s3_keys}


def cp_to_s3(local: Path, s3_key: str, content_type: str | None = None) -> None:
    s3_dest = f"s3://{S3_BUCKET}/{s3_key}"
    args = ["aws", "s3", "cp", str(local), s3_dest]
    if content_type:
        args += ["--content-type", content_type]
    print(f"   ↑ {local}")
    print(f"     → {s3_dest}")
    subprocess.run(args, check=True)


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    work_dir = WORK_ROOT / date
    bundle_path = work_dir / "bundle.json"
    qr_src = work_dir / "qr.png"
    if not bundle_path.exists():
        raise SystemExit(f"❌ bundle.json not found at {bundle_path}. Run step 4 first.")
    if not qr_src.exists():
        raise SystemExit(f"❌ qr.png not found at {qr_src}. Run step 5 first.")

    if not SITE_DIR.exists():
        raise SystemExit(f"❌ site dir not found: {SITE_DIR}")

    manifest = json.loads(bundle_path.read_text(encoding="utf-8"))

    # 1. Render and write files locally
    news_root = SITE_DIR / "news"
    day_dir = news_root / date
    day_dir.mkdir(parents=True, exist_ok=True)

    day_html = render_day_page(date, manifest, "qr.png")
    day_html_path = day_dir / "index.html"
    day_html_path.write_text(day_html, encoding="utf-8")
    shutil.copy2(qr_src, day_dir / "qr.png")

    archive_html = render_archive_page(news_root)
    archive_html_path = news_root / "index.html"
    archive_html_path.write_text(archive_html, encoding="utf-8")

    print(f"📝 Wrote local site files under {news_root}")
    print(f"   {day_html_path}")
    print(f"   {day_dir}/qr.png")
    print(f"   {archive_html_path}")
    print()

    # Map local files to S3 keys; check for clobber.
    upload_plan = [
        (day_html_path, f"news/{date}/index.html", "text/html"),
        (day_dir / "qr.png", f"news/{date}/qr.png", "image/png"),
        (archive_html_path, "news/index.html", "text/html"),
    ]
    print("Upload plan (local → s3):")
    s3_keys = [k for _, k, _ in upload_plan]
    clobber_map = check_destination_for_clobber(s3_keys)
    for local, key, _ct in upload_plan:
        dest = f"s3://{S3_BUCKET}/{key}"
        verb = "OVERWRITE" if clobber_map[key] else "create"
        # The rolling /news/index.html is expected to be overwritten on every
        # publish; flag everything else loudly.
        suffix = " (rolling archive page, expected)" if key == "news/index.html" and clobber_map[key] else ""
        print(f"  [{verb}] {local}")
        print(f"          → {dest}{suffix}")
    unexpected_overwrites = [
        k for k, c in clobber_map.items() if c and k != "news/index.html"
    ]
    if unexpected_overwrites and args.commit:
        raise SystemExit(
            f"❌ Refusing to overwrite unexpected keys on the website bucket:\n"
            f"   {unexpected_overwrites}\n"
            f"   This would clobber an existing day's published page. If this run is a\n"
            f"   re-publish you actually want, manually delete those S3 keys first."
        )
    if unexpected_overwrites:
        print(f"   ⚠ would overwrite (use a different --date or delete manually): {unexpected_overwrites}")
    print()

    if not args.commit:
        print("--- DRY RUN — no git commit, no S3 upload ---")
        print("Re-run with --commit to deploy.")
        return 0

    # 2. Git commit in the site repo
    print("📦 Committing to git...")
    subprocess.run(["git", "-C", str(SITE_REPO), "add",
                    str(day_html_path.relative_to(SITE_REPO)),
                    str((day_dir / "qr.png").relative_to(SITE_REPO)),
                    str(archive_html_path.relative_to(SITE_REPO))],
                   check=True)
    diff_check = subprocess.run(
        ["git", "-C", str(SITE_REPO), "diff", "--cached", "--quiet"],
    )
    if diff_check.returncode == 0:
        print("   (nothing to commit — files match HEAD)")
    else:
        subprocess.run(
            ["git", "-C", str(SITE_REPO), "commit", "-m", f"news: publish {date}"],
            check=True,
        )
        print(f"   ✓ committed news: publish {date}")

    # 3. Pre-flight bucket integrity check
    preflight_bucket_check()

    # 4. cp-only S3 uploads
    print(f"📤 Uploading to s3://{S3_BUCKET}/ (cp-only, no deletes)...")
    for local, key, ct in upload_plan:
        cp_to_s3(local, key, ct)
    print()
    print(f"🎉 Published https://sixwandsstudios.com/news/{date}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
