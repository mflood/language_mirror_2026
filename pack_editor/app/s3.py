from __future__ import annotations

import logging
from pathlib import Path

import boto3

from app.settings import settings

logger = logging.getLogger(__name__)


def _client():
    kwargs = {"region_name": settings.aws_region or "us-east-1"}
    if settings.aws_access_key_id and settings.aws_secret_access_key:
        kwargs["aws_access_key_id"] = settings.aws_access_key_id
        kwargs["aws_secret_access_key"] = settings.aws_secret_access_key
    return boto3.client("s3", **kwargs)


def s3_key_for_track(project_id: str, pack_id: str, filename: str) -> str:
    prefix = settings.s3_editor_prefix.strip("/")
    return f"{prefix}/projects/{project_id}/packs/{pack_id}/tracks/{filename}"


def upload_file(local_path: Path, s3_key: str) -> None:
    logger.info("Uploading %s -> s3://%s/%s", local_path.name, settings.s3_bucket_name, s3_key)
    _client().upload_file(str(local_path), settings.s3_bucket_name, s3_key)


def generate_presigned_url(s3_key: str, expires_in: int = 3600) -> str:
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.s3_bucket_name, "Key": s3_key},
        ExpiresIn=expires_in,
    )


def delete_file(s3_key: str) -> None:
    _client().delete_object(Bucket=settings.s3_bucket_name, Key=s3_key)
