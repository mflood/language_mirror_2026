"""Bundle production pipeline for LanguageMirror.

This package provides a CLI (`python -m bundle_pipeline ...`) that supports:
- init/download/transcribe/curate/assemble/publish

It is intentionally designed to produce a remote manifest compatible with the
LanguageMirror iOS app's `BundleManifest` / `BundleTrack` schema.
"""

__all__ = ["__version__"]

__version__ = "0.1.0"


