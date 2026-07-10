"""Edition plumbing shared by steps 2–6.

The daily pipeline produces two editions from one curate pass:
  ko — Korean-audio pack for English speakers learning Korean (the original)
  en — English-audio pack for Korean speakers learning English (mirror)

Per-edition work artifacts share work/<date>/ with a filename suffix:
script.json / script_en.json, audio/ / audio_en/, bundle.json / bundle_en.json.
"""

from __future__ import annotations

EDITIONS = ("ko", "en")


def suffix(edition: str) -> str:
    """Filename suffix for per-edition artifacts ("" for ko, "_en" for en)."""
    if edition not in EDITIONS:
        raise ValueError(f"unknown edition {edition!r}")
    return "" if edition == "ko" else "_en"


def add_edition_arg(parser) -> None:
    parser.add_argument("--edition", choices=list(EDITIONS), default="ko",
                        help="ko = Korean-audio (default, original behavior); "
                             "en = English-audio for Korean learners")
