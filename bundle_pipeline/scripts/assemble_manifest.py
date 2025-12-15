#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.assemble import assemble_manifest


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Assemble final BundleManifest JSON for iOS import")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--output", type=Path, help="Output manifest (default: work/<bundle_id>/bundle.json)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    wp.ensure_dirs()

    out = args.output or wp.manifest_path
    _manifest, written = assemble_manifest(work_root=args.work_root, bundle_id=args.bundle_id)
    if written != out:
        # If the caller requested a different output path, copy the file.
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(written.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Wrote: {out}")
    else:
        print(f"Wrote: {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


