from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


def parse_s3_uri(s3_uri: str) -> tuple[str, str]:
    """
    Parse S3 URI format: s3://bucket/key/prefix/
    Returns: (bucket, key_prefix_without_leading_slash_and_without_trailing_slash)
    """
    if not s3_uri.startswith("s3://"):
        raise ValueError("S3 URI must start with s3://")
    path = s3_uri[5:]
    parts = path.split("/", 1)
    bucket = parts[0]
    key_prefix = parts[1] if len(parts) > 1 else ""
    key_prefix = key_prefix.strip("/")
    return bucket, key_prefix


def _iter_s3_objects(s3_client, bucket: str, prefix: str) -> Iterable[dict]:
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []) or []:
            yield obj


def download_prefix_to_dir(source_s3: str, dest_dir: Path) -> list[Path]:
    """
    Downloads all objects under a given S3 prefix into dest_dir (flat).
    Returns list of downloaded file paths.
    """
    import boto3

    bucket, key_prefix = parse_s3_uri(source_s3)
    if key_prefix and not key_prefix.endswith("/"):
        key_prefix += "/"

    s3 = boto3.client("s3")
    dest_dir.mkdir(parents=True, exist_ok=True)

    downloaded: list[Path] = []
    for obj in _iter_s3_objects(s3, bucket, key_prefix):
        key = obj["Key"]
        if key.endswith("/"):
            continue
        filename = key.split("/")[-1]
        out_path = dest_dir / filename
        s3.download_file(bucket, key, str(out_path))
        downloaded.append(out_path)
    return downloaded


def upload_files(bucket: str, key_prefix: str, files: list[Path]) -> None:
    """
    Upload files to s3://bucket/key_prefix/<filename>.
    """
    import boto3

    s3 = boto3.client("s3")
    key_prefix = key_prefix.strip("/")
    if key_prefix:
        key_prefix += "/"

    for f in files:
        key = f"{key_prefix}{f.name}"
        s3.upload_file(str(f), bucket, key)


