#!/usr/bin/env python3
from __future__ import annotations

import argparse
import logging
from pathlib import Path

from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.assemble import assemble_manifest

logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Assemble final BundleManifest JSON for iOS import")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--output", type=Path, help="Output manifest (default: work/<bundle_id>/bundle.json)")
    p.add_argument("--verbose", action="store_true", help="Enable debug logging")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=(logging.DEBUG if args.verbose else logging.INFO),
        format="%(levelname)s:%(name)s:%(message)s",
    )
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    wp.ensure_dirs()

    out = args.output or wp.manifest_path
    logger.info(
        "Starting manifest assembly: bundle_id=%s work_root=%s config=%s output=%s",
        args.bundle_id,
        str(args.work_root),
        str(cfg_path),
        str(out),
    )
    _manifest, written = assemble_manifest(work_root=args.work_root, bundle_id=args.bundle_id)
    if written != out:
        # If the caller requested a different output path, copy the file.
        out.parent.mkdir(parents=True, exist_ok=True)
        logger.debug("Reading manifest for copy: %s", str(written))
        txt = written.read_text(encoding="utf-8")
        logger.debug("Writing copied manifest: %s", str(out))
        out.write_text(txt, encoding="utf-8")
        logger.info("Wrote: %s", str(out))
    else:
        logger.info("Wrote: %s", str(written))
    logger.info("Completed manifest assembly: output=%s", str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


