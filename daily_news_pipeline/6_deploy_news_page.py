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
    ~/Desktop/sixwandsstudiosllc/sixwands.com/news/<date>/meta.json
    ~/Desktop/sixwandsstudiosllc/sixwands.com/news/index.html  (rolling archive)

The day page is a full study sheet: EN+KO story titles, vocabulary table,
easy + natural Korean summaries, and a collapsible English translation. Content
comes from work/<date>/script.json; audio URLs come from work/<date>/bundle.json.

Safety: defaults to dry-run. Pass --commit to git-commit + upload. Existing
published day pages are never overwritten unless --redeploy is passed.

Usage:
    python 6_deploy_news_page.py [--date YYYY-MM-DD] [--commit] [--redeploy]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import subprocess
import sys
from pathlib import Path

from pagesmith import news_archive, news_day
from publisher import check_clobber, load_destination, publish, require_no_clobber
from studypack.adapters import news as news_adapter

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

SITE_REPO = Path.home() / "Desktop" / "sixwandsstudiosllc"
SITE_DIR = SITE_REPO / "sixwands.com"

# All bucket/CloudFront/protected-key infrastructure lives in the publisher
# destinations registry (~/.langpack/publisher.yaml), destination "website".
DESTINATION = "website"

KO_MONTHS = ["", "1월", "2월", "3월", "4월", "5월", "6월", "7월", "8월", "9월", "10월", "11월", "12월"]
EN_MONTHS = ["", "January", "February", "March", "April", "May", "June",
             "July", "August", "September", "October", "November", "December"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Deploy today's news page to sixwandsstudios.com")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--commit", action="store_true", help="Git-commit + upload to S3.")
    p.add_argument("--redeploy", action="store_true",
                   help="Allow overwriting an already-published day page (still cp-only, never deletes).")
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


def render_day_page(date: str, manifest: dict, script: dict, qr_filename: str) -> str:
    """Render via pagesmith (templates live there, byte-identical to the
    pages this module used to render inline)."""
    pack, warnings = news_adapter.convert(script)
    for w in warnings:
        print(f"  ⚠ studypack: {w}", file=sys.stderr)
    _, title_en = render_date_titles(date)
    track_url = manifest["packs"][0]["tracks"][0]["url"]
    manifest_url = track_url.rsplit("/", 1)[0] + "/bundle.json"
    app_url = f"languagemirror://bundle?url={manifest_url.replace(':', '%3A').replace('/', '%2F')}"
    return news_day.render(pack, title_en=title_en,
                           qr_filename=qr_filename, app_url=app_url)


def build_day_meta(date: str, script: dict) -> dict:
    """Small per-day sidecar consumed by the archive page renderer."""
    title_ko, title_en = render_date_titles(date)
    return {
        "date": date,
        "title_en": title_en,
        "title_ko": title_ko,
        "stories": [
            {
                "title_en": s.get("track_title_en", ""),
                "title_ko": s.get("track_title_ko", ""),
                "source": s.get("source", ""),
            }
            for s in script["stories"]
        ],
    }


def render_archive_page(news_root: Path) -> str:
    """Scan date subdirs newest-first, build entries from meta.json, render
    via pagesmith."""
    day_dirs = sorted(
        (p.name for p in news_root.iterdir()
         if p.is_dir() and len(p.name) == 10 and p.name[4] == "-"),
        reverse=True,
    )
    days = []
    for d in day_dirs[:60]:  # last 60 days max in the archive
        _, en = render_date_titles(d)
        preview = None
        meta_path = news_root / d / "meta.json"
        if meta_path.exists():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
                titles = [s["title_en"] for s in meta.get("stories", []) if s.get("title_en")]
                if titles:
                    preview = " · ".join(titles)
            except (json.JSONDecodeError, KeyError):
                pass
        days.append({"date": d, "title_en": en, "preview": preview})
    return news_archive.render(days)


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    work_dir = WORK_ROOT / date
    bundle_path = work_dir / "bundle.json"
    script_path = work_dir / "script.json"
    qr_src = work_dir / "qr.png"
    if not bundle_path.exists():
        raise SystemExit(f"❌ bundle.json not found at {bundle_path}. Run step 4 first.")
    if not script_path.exists():
        raise SystemExit(f"❌ script.json not found at {script_path}. Run step 2 first.")
    if not qr_src.exists():
        raise SystemExit(f"❌ qr.png not found at {qr_src}. Run step 5 first.")

    if not SITE_DIR.exists():
        raise SystemExit(f"❌ site dir not found: {SITE_DIR}")

    manifest = json.loads(bundle_path.read_text(encoding="utf-8"))
    script = json.loads(script_path.read_text(encoding="utf-8"))

    # 1. Render and write files locally
    news_root = SITE_DIR / "news"
    day_dir = news_root / date
    day_dir.mkdir(parents=True, exist_ok=True)

    day_html = render_day_page(date, manifest, script, "qr.png")
    day_html_path = day_dir / "index.html"
    day_html_path.write_text(day_html, encoding="utf-8")
    shutil.copy2(qr_src, day_dir / "qr.png")

    meta = build_day_meta(date, script)
    meta_path = day_dir / "meta.json"
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    archive_html = render_archive_page(news_root)
    archive_html_path = news_root / "index.html"
    archive_html_path.write_text(archive_html, encoding="utf-8")

    print(f"📝 Wrote local site files under {news_root}")
    print(f"   {day_html_path}")
    print(f"   {day_dir}/qr.png")
    print(f"   {meta_path}")
    print(f"   {archive_html_path}")
    print()

    # Publish via the langpack publisher (gates + upload + verify + invalidate).
    dest = load_destination(DESTINATION)
    plan = [
        (day_html_path, f"news/{date}/index.html"),
        (day_dir / "qr.png", f"news/{date}/qr.png"),
        (meta_path, f"news/{date}/meta.json"),
        (archive_html_path, "news/index.html"),
    ]

    if args.commit:
        # Clobber gate BEFORE the git commit so a refused publish leaves the
        # site repo untouched (matches the original step-6 ordering).
        clobber_map = check_clobber(dest, [k for _, k in plan])
        require_no_clobber(dest, clobber_map,
                           allow=("news/index.html",), redeploy=args.redeploy)

        print("📦 Committing to git...")
        subprocess.run(["git", "-C", str(SITE_REPO), "add",
                        str(day_html_path.relative_to(SITE_REPO)),
                        str((day_dir / "qr.png").relative_to(SITE_REPO)),
                        str(meta_path.relative_to(SITE_REPO)),
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

    publish(dest, plan,
            allow_overwrite_keys=("news/index.html",),  # rolling archive page
            redeploy=args.redeploy,
            invalidate_paths=[f"/news/{date}/*", "/news/index.html"],
            commit=args.commit)

    if not args.commit:
        print("Re-run with --commit to deploy.")
        return 0

    print()
    print(f"🎉 Published https://sixwandsstudios.com/news/{date}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
