from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any


def _require(d: dict[str, Any], key: str) -> Any:
    if key not in d or d[key] is None:
        raise ValueError(f"Missing required config field: {key}")
    return d[key]


@dataclass(frozen=True)
class PublishConfig:
    publish_bucket: str
    publish_prefix_template: str
    cloudfront_https_base: str
    cloudfront_prefix_template: str

    @staticmethod
    def load(path: Path) -> "PublishConfig":
        import yaml  # dependency: pyyaml

        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        return PublishConfig(
            publish_bucket=str(_require(data, "publish_bucket")),
            publish_prefix_template=str(_require(data, "publish_prefix_template")),
            cloudfront_https_base=str(_require(data, "cloudfront_https_base")).rstrip("/"),
            cloudfront_prefix_template=str(_require(data, "cloudfront_prefix_template")).strip(),
        )

    def publish_prefix(self, bundle_id: str) -> str:
        return self.publish_prefix_template.format(bundle_id=bundle_id).strip("/")

    def cloudfront_prefix(self, bundle_id: str) -> str:
        p = self.cloudfront_prefix_template.format(bundle_id=bundle_id)
        if not p.startswith("/"):
            p = "/" + p
        return p.rstrip("/")

    def manifest_https_url(self, bundle_id: str, manifest_filename: str = "bundle.json") -> str:
        return f"{self.cloudfront_https_base}{self.cloudfront_prefix(bundle_id)}/{manifest_filename}"


@dataclass(frozen=True)
class BundleConfig:
    bundle_id: str
    source_s3: str
    language_code: str
    bundle_title: str
    pack_title: str
    author: str | None
    cover_url: str | None
    cover_filename: str | None
    whisper_model: str
    gpt_model: str
    publish_config_path: Path

    @staticmethod
    def default_path(work_root: Path, bundle_id: str) -> Path:
        return work_root / bundle_id / "bundle.yaml"

    @staticmethod
    def load(path: Path) -> "BundleConfig":
        import yaml  # dependency: pyyaml

        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        bundle_id = str(_require(data, "bundle_id"))
        bundle_title = str(data.get("bundle_title") or bundle_id)
        return BundleConfig(
            bundle_id=bundle_id,
            source_s3=str(_require(data, "source_s3")),
            language_code=str(_require(data, "language_code")),
            bundle_title=bundle_title,
            pack_title=str(data.get("pack_title") or bundle_title),
            author=data.get("author"),
            cover_url=data.get("cover_url"),
            cover_filename=data.get("cover_filename"),
            whisper_model=str(data.get("whisper_model") or "base"),
            gpt_model=str(data.get("gpt_model") or "gpt-4o-mini"),
            publish_config_path=Path(str(data.get("publish_config_path") or "bundle_publish_config.yaml")),
        )

    def dump_yaml(self) -> str:
        import yaml  # dependency: pyyaml

        obj = {
            "bundle_id": self.bundle_id,
            "source_s3": self.source_s3,
            "language_code": self.language_code,
            "bundle_title": self.bundle_title,
            "pack_title": self.pack_title,
            "author": self.author,
            "cover_url": self.cover_url,
            "cover_filename": self.cover_filename,
            "whisper_model": self.whisper_model,
            "gpt_model": self.gpt_model,
            "publish_config_path": str(self.publish_config_path),
        }
        return yaml.safe_dump(obj, sort_keys=False, allow_unicode=True)


