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
import html
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

# CloudFront distribution fronting sixwandsstudios.com — uploaded pages are
# invalidated after each publish so edges don't serve stale copies for up to
# the default 24h TTL.
CLOUDFRONT_DISTRIBUTION_ID = "E3FOHY8GP6GID3"

APP_STORE_URL = "https://apps.apple.com/us/app/language-mirror/id6761317026"

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

CIRCLED = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]


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


def esc(s: str) -> str:
    return html.escape(str(s), quote=True)


SITE_NAV = """  <nav class="nav">
    <a href="/index.html" class="nav-brand">Six Wands Studios</a>
    <button class="nav-toggle" aria-label="Toggle menu" onclick="this.parentElement.classList.toggle('open')">
      <span></span><span></span><span></span>
    </button>
    <ul class="nav-links">
      <li><a href="/index.html">Home</a></li>
      <li><a href="/nardo.html">Nardo</a></li>
      <li><a href="/language-mirror.html">Language Mirror</a></li>
      <li><a href="/news/" class="active">Daily News</a></li>
      <li><a href="/support.html">Support</a></li>
    </ul>
  </nav>"""

SITE_FOOTER = """  <footer>
    <p class="studio-mark">&#9776;&#9776; Six Wands Studios LLC</p>
    <p>&copy; 2026</p>
    <nav class="footer-links">
      <a href="/support.html">Contact</a>
      <a href="/language-mirror-privacy.html">Privacy Policy</a>
    </nav>
  </footer>"""

NEWS_CSS = """    .news-wrap { max-width: 720px; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
    .news-head { text-align: center; padding-bottom: 1rem; }
    .news-head h1 { font-family: var(--serif); font-size: 2rem; font-weight: 600; }
    .news-head .ko-title { font-family: var(--serif); font-size: 1.25rem; color: var(--cream); font-style: italic; margin-top: 0.35rem; }
    .qr-block { text-align: center; margin: 1.5rem 0 0.5rem; }
    .qr-block .qr { display: block; margin: 0 auto 1.25rem; max-width: 240px; border-radius: 12px; }
    .qr-block .hint { font-size: 0.85rem; color: var(--white-dim); margin-top: 1rem; }
    .qr-block .hint a { color: var(--red-light); text-decoration: none; }
    .qr-block .hint a:hover { text-decoration: underline; }
    .howto { font-size: 0.8rem; color: var(--gray); letter-spacing: 0.04em; margin-top: 0.75rem; }
    .news-story { margin-top: 3rem; padding-top: 2rem; border-top: 1px solid var(--gray-dark); }
    .news-story h2 { font-family: var(--serif); font-size: 1.4rem; font-weight: 600; }
    .news-story .ko-title { font-size: 1.05rem; color: var(--cream); margin-top: 0.3rem; }
    .news-story .source { font-size: 0.75rem; color: var(--gray); letter-spacing: 0.06em; text-transform: uppercase; margin-top: 0.4rem; }
    .news-story .source a { color: var(--gray); }
    .news-story .source a:hover { color: var(--red-light); }
    .news-story h3 { font-size: 0.8rem; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--white-dim); margin: 1.75rem 0 0.75rem; }
    .vocab-table { width: 100%; border-collapse: collapse; font-size: 0.95rem; }
    .vocab-table td { padding: 0.4rem 0.75rem 0.4rem 0; border-bottom: 1px solid var(--gray-dark); vertical-align: top; }
    .vocab-table td:first-child { white-space: nowrap; color: var(--white); font-weight: 500; }
    .vocab-table td:last-child { color: var(--white-dim); }
    .summary-list { padding-left: 1.4rem; line-height: 1.9; }
    .summary-list li { margin: 0.3rem 0; }
    .summary-list[lang="ko"] { font-size: 1.02rem; }
    details.en-summary { margin-top: 1rem; }
    details.en-summary summary { cursor: pointer; font-size: 0.85rem; color: var(--red-light); letter-spacing: 0.04em; }
    details.en-summary summary:hover { color: var(--white); }
    .archive-link { display: inline-block; margin-top: 3rem; color: var(--red-light); text-decoration: none; }
    .archive-link:hover { text-decoration: underline; }"""


def render_day_page(date: str, manifest: dict, script: dict, qr_filename: str) -> str:
    pack = manifest["packs"][0]
    title_ko = manifest["title"]
    _, title_en = render_date_titles(date)

    manifest_url = pack["tracks"][0]["url"].rsplit("/", 1)[0] + "/bundle.json"
    app_url = f"languagemirror://bundle?url={manifest_url.replace(':', '%3A').replace('/', '%2F')}"

    story_sections = []
    for i, story in enumerate(script["stories"]):
        num = CIRCLED[i] if i < len(CIRCLED) else f"{i + 1}."
        vocab_rows = "\n".join(
            f'        <tr><td lang="ko">{esc(v["ko"])}</td><td>{esc(v["en"])}</td></tr>'
            for v in story.get("vocab", [])
        )
        def ko_list(val) -> str:
            if isinstance(val, str):
                val = [val]
            return "\n".join(f"        <li>{esc(s)}</li>" for s in (val or []))

        summary_sections = []
        if story.get("summary_ko_easy"):
            summary_sections.append(
                "      <h3>Easy Korean Summary · 쉬운 요약 (해요체)</h3>\n"
                '      <ol class="summary-list" lang="ko">\n'
                f'{ko_list(story["summary_ko_easy"])}\n'
                "      </ol>"
            )
        if story.get("summary_ko_natural"):
            summary_sections.append(
                "      <h3>Natural Korean Summary · 자연스러운 요약 (습니다체)</h3>\n"
                '      <ol class="summary-list" lang="ko">\n'
                f'{ko_list(story["summary_ko_natural"])}\n'
                "      </ol>"
            )
        if not summary_sections and story.get("summary_ko"):
            # Legacy single-tier schema (earliest runs).
            summary_sections.append(
                "      <h3>Korean Summary · 한국어 요약</h3>\n"
                '      <ol class="summary-list" lang="ko">\n'
                f'{ko_list(story["summary_ko"])}\n'
                "      </ol>"
            )
        summaries_html = "\n".join(summary_sections)
        en_summary = story.get("summary_en", [])
        if isinstance(en_summary, str):
            en_summary = [en_summary]
        en_items = "\n".join(f"          <li>{esc(s)}</li>" for s in en_summary)
        source_html = ""
        if story.get("source"):
            src = esc(story["source"])
            if story.get("link"):
                source_html = f'      <p class="source">Source: <a href="{esc(story["link"])}" rel="noopener">{src} ↗</a></p>'
            else:
                source_html = f'      <p class="source">Source: {src}</p>'

        story_sections.append(f"""    <section class="news-story">
      <h2>{num} {esc(story.get("track_title_en", ""))}</h2>
      <p class="ko-title" lang="ko">{esc(story.get("track_title_ko", ""))}</p>
{source_html}
      <h3>Vocabulary · 어휘</h3>
      <table class="vocab-table">
{vocab_rows}
      </table>
{summaries_html}
      <details class="en-summary">
        <summary>Show English translation</summary>
        <ol class="summary-list">
{en_items}
        </ol>
      </details>
    </section>""")
    stories_html = "\n".join(story_sections)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="description" content="{esc(title_en)} — a Korean listening practice pack from Language Mirror: vocabulary, example sentences, and two levels of Korean summary for each story.">
  <title>{esc(title_en)} · Six Wands Studios</title>
  <link rel="stylesheet" href="/style.css">
  <style>
{NEWS_CSS}
  </style>
</head>
<body>
{SITE_NAV}
  <main class="news-wrap">
    <header class="news-head">
      <h1>{esc(title_en)}</h1>
      <p class="ko-title" lang="ko">{esc(title_ko)}</p>
    </header>
    <div class="qr-block">
      <img class="qr" src="{esc(qr_filename)}" alt="QR code that loads this news pack in the Language Mirror app">
      <a class="app-store-badge" href="{esc(app_url)}">Open in Language Mirror</a>
      <p class="hint">Don't have the app? <a href="{APP_STORE_URL}">Download Language Mirror on the App Store</a>, then scan the code above.</p>
      <p class="howto">1 · Get the app &nbsp;&nbsp; 2 · Scan the QR code or tap the button &nbsp;&nbsp; 3 · Loop, shadow, repeat</p>
    </div>
{stories_html}
    <a class="archive-link" href="/news/">← All daily packs</a>
  </main>
{SITE_FOOTER}
</body>
</html>
"""


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


ARCHIVE_CSS = """    .archive-wrap { max-width: 720px; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
    .archive-head { text-align: center; padding-bottom: 1.5rem; }
    .archive-head h1 { font-family: var(--serif); font-size: 2.2rem; font-weight: 600; }
    .archive-head .sub { color: var(--white-dim); max-width: 480px; margin: 0.75rem auto 1.5rem; line-height: 1.8; font-size: 0.95rem; }
    .archive-head .links { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; align-items: center; }
    .archive-head .about-link { color: var(--red-light); text-decoration: none; font-size: 0.9rem; }
    .archive-head .about-link:hover { text-decoration: underline; }
    .day-list { list-style: none; padding: 0; margin-top: 2.5rem; }
    .day-list li { padding: 1.1rem 0; border-bottom: 1px solid var(--gray-dark); }
    .day-list a.day-link { font-family: var(--serif); font-size: 1.25rem; color: var(--white); text-decoration: none; }
    .day-list a.day-link:hover { color: var(--red-light); }
    .day-list .preview { font-size: 0.85rem; color: var(--white-dim); margin-top: 0.35rem; line-height: 1.7; }"""


def render_archive_page(news_root: Path) -> str:
    """List all date subdirs newest-first with story previews from meta.json."""
    days = sorted(
        (p.name for p in news_root.iterdir() if p.is_dir() and len(p.name) == 10 and p.name[4] == "-"),
        reverse=True,
    )
    items = []
    for d in days[:60]:  # last 60 days max in the archive
        _, en = render_date_titles(d)
        preview_html = ""
        meta_path = news_root / d / "meta.json"
        if meta_path.exists():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
                titles = [s["title_en"] for s in meta.get("stories", []) if s.get("title_en")]
                if titles:
                    preview_html = f'\n      <p class="preview">{esc(" · ".join(titles))}</p>'
            except (json.JSONDecodeError, KeyError):
                pass
        items.append(f"""    <li>
      <a class="day-link" href="{d}/">{esc(en)}</a>{preview_html}
    </li>""")
    items_html = "\n".join(items) or "    <li><em>No days published yet.</em></li>"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="description" content="Daily Korean News from Language Mirror — a fresh Korean listening practice pack every weekday: U.S. news rewritten in learner-friendly Korean with vocabulary and two levels of summary.">
  <title>Daily Korean News · Six Wands Studios</title>
  <link rel="stylesheet" href="/style.css">
  <style>
{ARCHIVE_CSS}
  </style>
</head>
<body>
{SITE_NAV}
  <main class="archive-wrap">
    <header class="archive-head">
      <h1>Daily Korean News</h1>
      <p class="sub">A new Language Mirror pack every weekday — U.S. news rewritten
         in learner-friendly Korean, with vocabulary, example sentences, and two
         levels of summary. Scan a day's QR code and it lands in your library.</p>
      <div class="links">
        <a class="app-store-badge" href="{APP_STORE_URL}">Download on the App Store</a>
        <a class="about-link" href="/language-mirror.html">About Language Mirror →</a>
      </div>
    </header>
    <ul class="day-list">
{items_html}
    </ul>
  </main>
{SITE_FOOTER}
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


def invalidate_cloudfront(paths: list[str]) -> None:
    """Fire-and-forget CloudFront invalidation for the given paths."""
    print(f"🌀 CloudFront invalidation ({CLOUDFRONT_DISTRIBUTION_ID}): {' '.join(paths)}")
    result = subprocess.run(
        ["aws", "cloudfront", "create-invalidation",
         "--distribution-id", CLOUDFRONT_DISTRIBUTION_ID,
         "--paths", *paths,
         "--query", "Invalidation.Id", "--output", "text"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        # Stale cache is annoying but not worth failing the publish over.
        print(f"   ⚠ invalidation failed (page may stay cached up to 24h): {result.stderr.strip()}")
    else:
        print(f"   ✓ invalidation created: {result.stdout.strip()} (completes in a few minutes)")


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

    # Map local files to S3 keys; check for clobber.
    upload_plan = [
        (day_html_path, f"news/{date}/index.html", "text/html"),
        (day_dir / "qr.png", f"news/{date}/qr.png", "image/png"),
        (meta_path, f"news/{date}/meta.json", "application/json"),
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
        if clobber_map[key] and key != "news/index.html" and args.redeploy:
            suffix = " (--redeploy: intentional overwrite)"
        print(f"  [{verb}] {local}")
        print(f"          → {dest}{suffix}")
    unexpected_overwrites = [
        k for k, c in clobber_map.items() if c and k != "news/index.html"
    ]
    if unexpected_overwrites and args.redeploy:
        print(f"   ⚠ --redeploy set: overwriting {len(unexpected_overwrites)} existing day key(s).")
        unexpected_overwrites = []
    if unexpected_overwrites and args.commit:
        raise SystemExit(
            f"❌ Refusing to overwrite unexpected keys on the website bucket:\n"
            f"   {unexpected_overwrites}\n"
            f"   This would clobber an existing day's published page. If this re-publish\n"
            f"   is intentional, re-run with --redeploy."
        )
    if unexpected_overwrites:
        print(f"   ⚠ would overwrite (pass --redeploy to allow): {unexpected_overwrites}")
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

    # 3. Pre-flight bucket integrity check
    preflight_bucket_check()

    # 4. cp-only S3 uploads
    print(f"📤 Uploading to s3://{S3_BUCKET}/ (cp-only, no deletes)...")
    for local, key, ct in upload_plan:
        cp_to_s3(local, key, ct)
    print()

    # 5. Invalidate CloudFront so edges pick up the new pages immediately
    invalidate_cloudfront([f"/news/{date}/*", "/news/index.html"])
    print()
    print(f"🎉 Published https://sixwandsstudios.com/news/{date}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
