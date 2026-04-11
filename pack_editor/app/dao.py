from __future__ import annotations

import secrets
from dataclasses import dataclass
from typing import Optional

from psycopg_pool import ConnectionPool

from app.settings import settings


@dataclass
class DAO:
    pool: ConnectionPool

    def healthcheck(self) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                cur.fetchone()

    # ── Users ──────────────────────────────────────────────────────────

    def create_user(self, email: str, full_name: Optional[str] = None, is_admin: bool = False) -> dict:
        access_code = secrets.token_urlsafe(12)
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO "user" (email, full_name, access_code, is_admin)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, email, full_name, access_code, is_admin, created_at;
                    """,
                    (email, full_name, access_code, is_admin),
                )
                row = cur.fetchone()
                conn.commit()
                return _user_row_to_dict(row)

    def get_user_by_email(self, email: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, email, full_name, access_code, is_admin, created_at
                    FROM "user"
                    WHERE email = %s;
                    """,
                    (email,),
                )
                row = cur.fetchone()
                return _user_row_to_dict(row) if row else None

    def get_user(self, user_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, email, full_name, access_code, is_admin, created_at
                    FROM "user"
                    WHERE id = %s;
                    """,
                    (user_id,),
                )
                row = cur.fetchone()
                return _user_row_to_dict(row) if row else None

    def list_users(self) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, email, full_name, access_code, is_admin, created_at
                    FROM "user"
                    ORDER BY created_at DESC;
                    """
                )
                return [_user_row_to_dict(row) for row in cur.fetchall()]

    def update_user_name(self, user_id: str, full_name: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    'UPDATE "user" SET full_name = %s WHERE id = %s;',
                    (full_name, user_id),
                )
                conn.commit()

    # ── Projects ───────────────────────────────────────────────────────

    def create_project(self, name: str, language_code: str, description: Optional[str] = None) -> dict:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO project (name, language_code, description)
                    VALUES (%s, %s, %s)
                    RETURNING id, name, language_code, description, created_at;
                    """,
                    (name, language_code, description),
                )
                row = cur.fetchone()
                conn.commit()
                return _project_row_to_dict(row)

    def get_project(self, project_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, name, language_code, description, created_at
                    FROM project
                    WHERE id = %s;
                    """,
                    (project_id,),
                )
                row = cur.fetchone()
                return _project_row_to_dict(row) if row else None

    def list_projects(self) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, name, language_code, description, created_at
                    FROM project
                    ORDER BY created_at DESC;
                    """
                )
                return [_project_row_to_dict(row) for row in cur.fetchall()]

    def list_projects_for_user(self, user_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT p.id, p.name, p.language_code, p.description, p.created_at
                    FROM project p
                    JOIN project_user pu ON p.id = pu.project_id
                    WHERE pu.user_id = %s
                    ORDER BY p.created_at DESC;
                    """,
                    (user_id,),
                )
                return [_project_row_to_dict(row) for row in cur.fetchall()]

    # ── Project-User assignment ────────────────────────────────────────

    def assign_user_to_project(self, project_id: str, user_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO project_user (project_id, user_id)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING;
                    """,
                    (project_id, user_id),
                )
                conn.commit()

    def unassign_user_from_project(self, project_id: str, user_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM project_user
                    WHERE project_id = %s AND user_id = %s;
                    """,
                    (project_id, user_id),
                )
                conn.commit()

    def get_project_users(self, project_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT u.id, u.email, u.full_name, u.access_code, u.is_admin, u.created_at
                    FROM "user" u
                    JOIN project_user pu ON u.id = pu.user_id
                    WHERE pu.project_id = %s
                    ORDER BY u.email;
                    """,
                    (project_id,),
                )
                return [_user_row_to_dict(row) for row in cur.fetchall()]

    def is_user_in_project(self, project_id: str, user_id: str) -> bool:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT 1 FROM project_user
                    WHERE project_id = %s AND user_id = %s;
                    """,
                    (project_id, user_id),
                )
                return cur.fetchone() is not None

    # ── Packs ──────────────────────────────────────────────────────────

    def create_pack(self, project_id: str, title: str, author: Optional[str] = None) -> dict:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO pack (project_id, title, author)
                    VALUES (%s, %s, %s)
                    RETURNING id, project_id, title, author, cover_url, status, created_at, updated_at;
                    """,
                    (project_id, title, author),
                )
                row = cur.fetchone()
                conn.commit()
                return _pack_row_to_dict(row)

    def get_pack(self, pack_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, project_id, title, author, cover_url, status, created_at, updated_at
                    FROM pack
                    WHERE id = %s;
                    """,
                    (pack_id,),
                )
                row = cur.fetchone()
                return _pack_row_to_dict(row) if row else None

    def update_pack(self, pack_id: str, title: Optional[str] = None, author: Optional[str] = None, status: Optional[str] = None) -> Optional[dict]:
        sets = []
        params = []
        if title is not None:
            sets.append("title = %s")
            params.append(title)
        if author is not None:
            sets.append("author = %s")
            params.append(author)
        if status is not None:
            sets.append("status = %s")
            params.append(status)
        if not sets:
            return self.get_pack(pack_id)
        sets.append("updated_at = now()")
        params.append(pack_id)
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    UPDATE pack SET {', '.join(sets)}
                    WHERE id = %s
                    RETURNING id, project_id, title, author, cover_url, status, created_at, updated_at;
                    """,
                    params,
                )
                row = cur.fetchone()
                conn.commit()
                return _pack_row_to_dict(row) if row else None

    def delete_pack(self, pack_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM pack WHERE id = %s;", (pack_id,))
                conn.commit()

    def list_packs_for_project(self, project_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, project_id, title, author, cover_url, status, created_at, updated_at
                    FROM pack
                    WHERE project_id = %s
                    ORDER BY created_at DESC;
                    """,
                    (project_id,),
                )
                return [_pack_row_to_dict(row) for row in cur.fetchall()]

    # ── Tracks ─────────────────────────────────────────────────────────

    def create_track(
        self,
        pack_id: str,
        title: str,
        filename: str,
        s3_key: str,
        duration_ms: Optional[int] = None,
        language_code: Optional[str] = None,
        display_order: int = 0,
    ) -> dict:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO track (pack_id, title, filename, s3_key, duration_ms, language_code, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, pack_id, title, filename, s3_key, duration_ms,
                              language_code, display_order, created_at;
                    """,
                    (pack_id, title, filename, s3_key, duration_ms, language_code, display_order),
                )
                row = cur.fetchone()
                conn.commit()
                return _track_row_to_dict(row)

    def get_track(self, track_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, pack_id, title, filename, s3_key, duration_ms,
                           language_code, display_order, created_at
                    FROM track
                    WHERE id = %s;
                    """,
                    (track_id,),
                )
                row = cur.fetchone()
                return _track_row_to_dict(row) if row else None

    def delete_track(self, track_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM track WHERE id = %s;", (track_id,))
                conn.commit()

    def get_next_track_order(self, pack_id: str) -> int:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT COALESCE(MAX(display_order), -1) + 1 FROM track WHERE pack_id = %s;",
                    (pack_id,),
                )
                return cur.fetchone()[0]

    def list_tracks_for_pack(self, pack_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, pack_id, title, filename, s3_key, duration_ms,
                           language_code, display_order, created_at
                    FROM track
                    WHERE pack_id = %s
                    ORDER BY display_order, created_at;
                    """,
                    (pack_id,),
                )
                return [_track_row_to_dict(row) for row in cur.fetchall()]

    # ── Jobs ───────────────────────────────────────────────────────────

    def create_job(self, track_id: str, job_type: str) -> dict:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO job (track_id, job_type)
                    VALUES (%s, %s)
                    RETURNING id, track_id, job_type, status, error_message, created_at, completed_at;
                    """,
                    (track_id, job_type),
                )
                row = cur.fetchone()
                conn.commit()
                return _job_row_to_dict(row)

    def get_job(self, job_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, track_id, job_type, status, error_message, created_at, completed_at
                    FROM job WHERE id = %s;
                    """,
                    (job_id,),
                )
                row = cur.fetchone()
                return _job_row_to_dict(row) if row else None

    def update_job_status(self, job_id: str, status: str, error_message: Optional[str] = None) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                if status in ("done", "failed"):
                    cur.execute(
                        "UPDATE job SET status = %s, error_message = %s, completed_at = now() WHERE id = %s;",
                        (status, error_message, job_id),
                    )
                else:
                    cur.execute(
                        "UPDATE job SET status = %s, error_message = %s WHERE id = %s;",
                        (status, error_message, job_id),
                    )
                conn.commit()

    def list_pending_jobs(self) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, track_id, job_type, status, error_message, created_at, completed_at
                    FROM job WHERE status = 'pending'
                    ORDER BY created_at;
                    """
                )
                return [_job_row_to_dict(row) for row in cur.fetchall()]

    def get_latest_job_for_track(self, track_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, track_id, job_type, status, error_message, created_at, completed_at
                    FROM job WHERE track_id = %s
                    ORDER BY created_at DESC LIMIT 1;
                    """,
                    (track_id,),
                )
                row = cur.fetchone()
                return _job_row_to_dict(row) if row else None

    # ── Clips ──────────────────────────────────────────────────────────

    def bulk_insert_clips(self, track_id: str, practice_set_id: str, clips: list[dict]) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                for i, c in enumerate(clips):
                    cur.execute(
                        """
                        INSERT INTO clip (track_id, practice_set_id, start_ms, end_ms, kind, title, display_order)
                        VALUES (%s, %s, %s, %s, %s, %s, %s);
                        """,
                        (track_id, practice_set_id, c["startMs"], c["endMs"],
                         c.get("kind", "drill"), c.get("title", ""), i),
                    )
                conn.commit()

    def list_clips_for_track(self, track_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, track_id, practice_set_id, start_ms, end_ms, kind, title, display_order
                    FROM clip WHERE track_id = %s
                    ORDER BY display_order;
                    """,
                    (track_id,),
                )
                return [_clip_row_to_dict(row) for row in cur.fetchall()]

    def get_clip(self, clip_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, track_id, practice_set_id, start_ms, end_ms, kind, title, display_order FROM clip WHERE id = %s;",
                    (clip_id,),
                )
                row = cur.fetchone()
                return _clip_row_to_dict(row) if row else None

    def update_clip(self, clip_id: str, **kwargs) -> Optional[dict]:
        allowed = {"start_ms", "end_ms", "kind", "title", "display_order"}
        sets, params = [], []
        for k, v in kwargs.items():
            if k in allowed and v is not None:
                sets.append(f"{k} = %s")
                params.append(v)
        if not sets:
            return self.get_clip(clip_id)
        params.append(clip_id)
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE clip SET {', '.join(sets)} WHERE id = %s "
                    "RETURNING id, track_id, practice_set_id, start_ms, end_ms, kind, title, display_order;",
                    params,
                )
                row = cur.fetchone()
                conn.commit()
                return _clip_row_to_dict(row) if row else None

    def create_clip(self, track_id: str, start_ms: int, end_ms: int, kind: str = "drill", title: str = "", practice_set_id: Optional[str] = None) -> dict:
        display_order = 0
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COALESCE(MAX(display_order), -1) + 1 FROM clip WHERE track_id = %s;", (track_id,))
                display_order = cur.fetchone()[0]
                cur.execute(
                    """
                    INSERT INTO clip (track_id, practice_set_id, start_ms, end_ms, kind, title, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, track_id, practice_set_id, start_ms, end_ms, kind, title, display_order;
                    """,
                    (track_id, practice_set_id, start_ms, end_ms, kind, title, display_order),
                )
                row = cur.fetchone()
                conn.commit()
                return _clip_row_to_dict(row)

    def delete_clip(self, clip_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM clip WHERE id = %s;", (clip_id,))
                conn.commit()

    def delete_clips_for_track(self, track_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM clip WHERE track_id = %s;", (track_id,))
                conn.commit()

    # ── Transcript Spans ───────────────────────────────────────────────

    def bulk_insert_transcript_spans(self, track_id: str, spans: list[dict], language_code: Optional[str] = None) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                for i, s in enumerate(spans):
                    cur.execute(
                        """
                        INSERT INTO transcript_span (track_id, start_ms, end_ms, text, speaker, language_code, display_order)
                        VALUES (%s, %s, %s, %s, %s, %s, %s);
                        """,
                        (track_id, s["startMs"], s["endMs"], s["text"],
                         s.get("speaker", ""), language_code, i),
                    )
                conn.commit()

    def list_spans_for_track(self, track_id: str) -> list[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, track_id, start_ms, end_ms, text, speaker, language_code, display_order
                    FROM transcript_span WHERE track_id = %s
                    ORDER BY display_order;
                    """,
                    (track_id,),
                )
                return [_span_row_to_dict(row) for row in cur.fetchall()]

    def get_span(self, span_id: str) -> Optional[dict]:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT id, track_id, start_ms, end_ms, text, speaker, language_code, display_order FROM transcript_span WHERE id = %s;",
                    (span_id,),
                )
                row = cur.fetchone()
                return _span_row_to_dict(row) if row else None

    def update_span(self, span_id: str, **kwargs) -> Optional[dict]:
        allowed = {"start_ms", "end_ms", "text", "speaker", "language_code", "display_order"}
        sets, params = [], []
        for k, v in kwargs.items():
            if k in allowed and v is not None:
                sets.append(f"{k} = %s")
                params.append(v)
        if not sets:
            return self.get_span(span_id)
        params.append(span_id)
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE transcript_span SET {', '.join(sets)} WHERE id = %s "
                    "RETURNING id, track_id, start_ms, end_ms, text, speaker, language_code, display_order;",
                    params,
                )
                row = cur.fetchone()
                conn.commit()
                return _span_row_to_dict(row) if row else None

    def create_span(self, track_id: str, start_ms: int, end_ms: int, text: str, speaker: str = "", language_code: Optional[str] = None) -> dict:
        display_order = 0
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COALESCE(MAX(display_order), -1) + 1 FROM transcript_span WHERE track_id = %s;", (track_id,))
                display_order = cur.fetchone()[0]
                cur.execute(
                    """
                    INSERT INTO transcript_span (track_id, start_ms, end_ms, text, speaker, language_code, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, track_id, start_ms, end_ms, text, speaker, language_code, display_order;
                    """,
                    (track_id, start_ms, end_ms, text, speaker, language_code, display_order),
                )
                row = cur.fetchone()
                conn.commit()
                return _span_row_to_dict(row)

    def delete_span(self, span_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM transcript_span WHERE id = %s;", (span_id,))
                conn.commit()

    def delete_spans_for_track(self, track_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM transcript_span WHERE track_id = %s;", (track_id,))
                conn.commit()

    # ── Practice Sets ──────────────────────────────────────────────────

    def create_practice_set(self, track_id: str, title: str, display_order: int = 0) -> dict:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO practice_set (track_id, title, display_order)
                    VALUES (%s, %s, %s)
                    RETURNING id, track_id, title, display_order;
                    """,
                    (track_id, title, display_order),
                )
                row = cur.fetchone()
                conn.commit()
                return {"id": str(row[0]), "track_id": str(row[1]), "title": row[2], "display_order": row[3]}

    def delete_practice_sets_for_track(self, track_id: str) -> None:
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM practice_set WHERE track_id = %s;", (track_id,))
                conn.commit()

    # ── Stats ──────────────────────────────────────────────────────────

    def get_project_member_counts(self) -> dict[str, int]:
        """Return {project_id: member_count} for all projects."""
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT project_id, COUNT(*) as cnt
                    FROM project_user
                    GROUP BY project_id;
                    """
                )
                return {str(row[0]): row[1] for row in cur.fetchall()}

    def get_project_pack_counts(self) -> dict[str, int]:
        """Return {project_id: pack_count} for all projects."""
        with self.pool.connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT project_id, COUNT(*) as cnt
                    FROM pack
                    GROUP BY project_id;
                    """
                )
                return {str(row[0]): row[1] for row in cur.fetchall()}


# ── Row helpers ────────────────────────────────────────────────────────

def _user_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "email": row[1],
        "full_name": row[2],
        "access_code": row[3],
        "is_admin": row[4],
        "created_at": row[5],
    }


def _project_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "name": row[1],
        "language_code": row[2],
        "description": row[3],
        "created_at": row[4],
    }


def _pack_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "project_id": str(row[1]),
        "title": row[2],
        "author": row[3],
        "cover_url": row[4],
        "status": row[5],
        "created_at": row[6],
        "updated_at": row[7],
    }


def _track_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "pack_id": str(row[1]),
        "title": row[2],
        "filename": row[3],
        "s3_key": row[4],
        "duration_ms": row[5],
        "language_code": row[6],
        "display_order": row[7],
        "created_at": row[8],
    }


def _job_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "track_id": str(row[1]),
        "job_type": row[2],
        "status": row[3],
        "error_message": row[4],
        "created_at": row[5],
        "completed_at": row[6],
    }


def _clip_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "track_id": str(row[1]),
        "practice_set_id": str(row[2]) if row[2] else None,
        "start_ms": row[3],
        "end_ms": row[4],
        "kind": row[5],
        "title": row[6],
        "display_order": row[7],
    }


def _span_row_to_dict(row) -> dict:
    return {
        "id": str(row[0]),
        "track_id": str(row[1]),
        "start_ms": row[2],
        "end_ms": row[3],
        "text": row[4],
        "speaker": row[5],
        "language_code": row[6],
        "display_order": row[7],
    }


# ── Singleton ──────────────────────────────────────────────────────────

_dao: Optional[DAO] = None


def get_dao() -> DAO:
    global _dao
    if _dao is None:
        if not settings.database_url:
            raise RuntimeError("DATABASE_URL is not set")
        pool = ConnectionPool(
            conninfo=settings.database_url,
            min_size=1,
            max_size=5,
            open=True,
        )
        _dao = DAO(pool=pool)
    return _dao
