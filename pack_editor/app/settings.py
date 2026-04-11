from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    env: str
    database_url: str
    admin_password: str
    session_secret_key: str
    s3_bucket_name: str
    s3_editor_prefix: str
    aws_region: str
    aws_access_key_id: str
    aws_secret_access_key: str
    cloudfront_base_url: str
    base_url: str
    google_client_id: str
    google_client_secret: str

    @property
    def is_prod(self) -> bool:
        return self.env.lower() in {"prod", "production"}

    @classmethod
    def from_env(cls) -> "Settings":
        admin_password = os.getenv("ADMIN_PASSWORD", "")
        session_secret_key = os.getenv("SESSION_SECRET_KEY", "")

        if not session_secret_key:
            import secrets
            session_secret_key = secrets.token_urlsafe(32)
            import warnings
            warnings.warn(
                "SESSION_SECRET_KEY not set - generating a random key. "
                "Sessions will not survive restarts. "
                "Set SESSION_SECRET_KEY in .env for persistence.",
                UserWarning,
                stacklevel=2,
            )

        env = os.getenv("ENV", "local")
        if env.lower() in {"prod", "production"} and not admin_password:
            raise ValueError("ADMIN_PASSWORD must be set in production")

        return cls(
            env=env,
            database_url=os.getenv("DATABASE_URL", ""),
            admin_password=admin_password,
            session_secret_key=session_secret_key,
            s3_bucket_name=os.getenv("S3_BUCKET_NAME", ""),
            s3_editor_prefix=os.getenv("S3_EDITOR_PREFIX", "editor"),
            aws_region=os.getenv("AWS_REGION", "us-east-1"),
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID", ""),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY", ""),
            cloudfront_base_url=os.getenv("CLOUDFRONT_BASE_URL", ""),
            base_url=os.getenv("BASE_URL", "http://localhost:8000"),
            google_client_id=os.getenv("GOOGLE_CLIENT_ID", ""),
            google_client_secret=os.getenv("GOOGLE_CLIENT_SECRET", ""),
        )


settings = Settings.from_env()
