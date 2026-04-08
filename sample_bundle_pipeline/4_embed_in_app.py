#!/usr/bin/env python3
"""
Step 4: Embed a published bundle into the iOS app.

Takes a local bundle.json + audio directory (typically the output of the
existing bundle_pipeline at work/<bundle_id>/) and copies them into the
iOS app's Resources/embedded_bundles/<bundle_id>/ folder, rewriting the
bundle.json so audio is referenced by filename instead of CloudFront URL.

The result is loadable by the app via:

    ImportSource.appBundleManifest(subdirectory: "embedded_bundles/<bundle_id>")

This step makes NO network calls and NO AWS calls. It only reads from the
local work directory and writes into the iOS source tree.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_WORK_ROOT = REPO_ROOT / "work"
DEFAULT_APP_RESOURCES = (
    REPO_ROOT
    / "LanguageMirror"
    / "LanguageMirror"
    / "2025-09-13"
    / "Resources"
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "Embed a published bundle into the iOS app's Resources folder. "
            "Reads from work/<bundle_id>/ and writes to "
            "Resources/embedded_bundles/<bundle_id>/."
        )
    )
    p.add_argument("--bundle-id", required=True, help="Bundle id (also the work and embed folder name)")
    p.add_argument(
        "--work-root",
        type=Path,
        default=DEFAULT_WORK_ROOT,
        help=f"Where work/<bundle_id> lives (default: {DEFAULT_WORK_ROOT})",
    )
    p.add_argument(
        "--app-resources",
        type=Path,
        default=DEFAULT_APP_RESOURCES,
        help=f"iOS app Resources/ directory (default: {DEFAULT_APP_RESOURCES})",
    )
    p.add_argument(
        "--bundle-json",
        type=Path,
        default=None,
        help="Path to bundle.json. Default: <work-root>/<bundle-id>/bundle.json",
    )
    p.add_argument(
        "--audio-dir",
        type=Path,
        default=None,
        help="Path to audio directory. Default: <work-root>/<bundle-id>/audio",
    )
    p.add_argument(
        "--force",
        action="store_true",
        help="Overwrite the destination embedded folder if it already exists",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would happen without writing any files",
    )
    return p.parse_args()


def safe_id(bundle_id: str) -> str:
    """Sanitize a bundle id for use as a filename prefix.
    Replaces anything that isn't alphanumeric, dash, or underscore with '_'.
    """
    out = []
    for ch in bundle_id:
        if ch.isalnum() or ch in ("-", "_"):
            out.append(ch)
        else:
            out.append("_")
    return "".join(out)


def rewrite_manifest_for_embed(
    manifest: dict[str, Any], bundle_id: str
) -> tuple[dict[str, Any], list[tuple[str, str]]]:
    """Strip URL fields, prefix filenames with the bundle id (so they don't
    collide with other embedded bundles in the flat .app root), and collect
    the list of (source_filename, prefixed_filename) pairs to copy.
    """
    new_manifest = json.loads(json.dumps(manifest))  # deep copy
    sid = safe_id(bundle_id)
    file_pairs: list[tuple[str, str]] = []

    for pack in new_manifest.get("packs", []):
        for track in pack.get("tracks", []):
            original = track.get("filename")
            if not original:
                url = track.get("url")
                if url:
                    original = url.rsplit("/", 1)[-1]
            if not original:
                continue
            prefixed = f"{sid}__{original}"
            file_pairs.append((original, prefixed))
            # Rewrite filename in manifest so the iOS resolver can find it
            track["filename"] = prefixed
            # Clear remote URL — embedded bundles don't need it.
            track["url"] = None

    return new_manifest, file_pairs


def main() -> int:
    args = parse_args()

    bundle_dir = args.work_root / args.bundle_id
    bundle_json_path = args.bundle_json or (bundle_dir / "bundle.json")
    audio_dir = args.audio_dir or (bundle_dir / "audio")

    if not bundle_json_path.exists():
        print(f"❌ Missing bundle.json at: {bundle_json_path}", file=sys.stderr)
        return 1
    if not audio_dir.exists():
        print(f"❌ Missing audio directory at: {audio_dir}", file=sys.stderr)
        return 1

    print(f"📖 Reading manifest: {bundle_json_path}")
    manifest = json.loads(bundle_json_path.read_text(encoding="utf-8"))
    new_manifest, file_pairs = rewrite_manifest_for_embed(manifest, args.bundle_id)

    sid = safe_id(args.bundle_id)
    out_dir = args.app_resources / "embedded_bundles" / args.bundle_id
    bundle_out = out_dir / f"{sid}.bundle.json"

    print(f"📂 Target: {out_dir}")
    print(f"📦 Bundle: {new_manifest.get('title')} ({new_manifest.get('id')})")
    print(f"🎧 Tracks needing audio: {len(file_pairs)}")
    print(f"🏷  Filename prefix: {sid}__")

    # Validate every needed source file exists
    missing: list[str] = []
    total_bytes = 0
    for original, _ in file_pairs:
        src = audio_dir / original
        if not src.exists():
            missing.append(original)
        else:
            total_bytes += src.stat().st_size

    if missing:
        print(f"❌ Missing audio files in {audio_dir}:", file=sys.stderr)
        for m in missing:
            print(f"   - {m}", file=sys.stderr)
        return 1

    print(f"📏 Total embedded audio size: {total_bytes / 1024 / 1024:.2f} MB")

    if args.dry_run:
        print()
        print("--- DRY RUN ---")
        print(f"Would create directory: {out_dir}")
        print(f"Would write {bundle_out.name} with url fields cleared and prefixed filenames")
        print(f"Would copy {len(file_pairs)} audio files ({total_bytes / 1024 / 1024:.2f} MB):")
        for original, prefixed in file_pairs:
            print(f"   {original}  →  {prefixed}")
        print()
        print("Re-run without --dry-run to actually embed.")
        return 0

    # Create / clean output directory
    if out_dir.exists():
        if not args.force:
            print(
                f"❌ Destination already exists: {out_dir}\n"
                f"   Pass --force to overwrite, or remove the directory first.",
                file=sys.stderr,
            )
            return 1
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Write rewritten bundle.json
    bundle_out.write_text(
        json.dumps(new_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"✅ Wrote {bundle_out.name}")

    # Copy audio files with prefixed names
    for original, prefixed in file_pairs:
        src = audio_dir / original
        dst = out_dir / prefixed
        shutil.copy2(src, dst)
        print(f"✅ Copied {original}  →  {prefixed} ({src.stat().st_size // 1024} KB)")

    print()
    print("🎉 Embed complete.")
    print()
    print("To load this bundle in the app, call:")
    print(f'    ImportSource.appBundleManifest(bundleId: "{args.bundle_id}")')
    print()
    print("The iOS resolver will look up the manifest as:")
    print(f'    Bundle.main.url(forResource: "{sid}.bundle", withExtension: "json")')
    print()
    print("⚠ IMPORTANT — IP review:")
    print("   This embeds the audio inside the app .ipa. Only do this for content")
    print("   you have rights to ship (your own recordings, Polly-generated audio,")
    print("   licensed material, etc.). Do NOT embed scraped or third-party audio.")
    print()
    print("To make this pack visible to users, add it to the Featured Packs catalog:")
    print(f"   LanguageMirror/.../Resources/featured_catalog.json")
    print("This is a deliberate second step — embedding alone does not surface it.")
    print()
    print("Re-archive the iOS app to ship the embedded bundle.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
