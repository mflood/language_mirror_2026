-- Users invited by admin, authenticate via Google OAuth
CREATE TABLE "user" (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT UNIQUE NOT NULL,
    full_name     TEXT,
    access_code   TEXT UNIQUE,
    is_admin      BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE project (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    language_code TEXT NOT NULL,
    description   TEXT,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE project_user (
    project_id UUID REFERENCES project(id) ON DELETE CASCADE,
    user_id    UUID REFERENCES "user"(id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE pack (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID REFERENCES project(id) ON DELETE CASCADE NOT NULL,
    title       TEXT NOT NULL,
    author      TEXT,
    cover_url   TEXT,
    status      TEXT DEFAULT 'draft',
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE track (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pack_id       UUID REFERENCES pack(id) ON DELETE CASCADE NOT NULL,
    title         TEXT NOT NULL,
    filename      TEXT NOT NULL,
    s3_key        TEXT NOT NULL,
    duration_ms   INT,
    language_code TEXT,
    display_order INT DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE practice_set (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id      UUID REFERENCES track(id) ON DELETE CASCADE NOT NULL,
    title         TEXT,
    display_order INT DEFAULT 0
);

CREATE TABLE clip (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id        UUID REFERENCES track(id) ON DELETE CASCADE NOT NULL,
    practice_set_id UUID REFERENCES practice_set(id) ON DELETE SET NULL,
    start_ms        INT NOT NULL,
    end_ms          INT NOT NULL,
    kind            TEXT NOT NULL DEFAULT 'drill',
    title           TEXT,
    display_order   INT DEFAULT 0
);

CREATE TABLE transcript_span (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id      UUID REFERENCES track(id) ON DELETE CASCADE NOT NULL,
    start_ms      INT NOT NULL,
    end_ms        INT NOT NULL,
    text          TEXT NOT NULL,
    speaker       TEXT,
    language_code TEXT,
    display_order INT DEFAULT 0
);

CREATE TABLE job (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    track_id      UUID REFERENCES track(id) ON DELETE CASCADE NOT NULL,
    job_type      TEXT NOT NULL,
    status        TEXT DEFAULT 'pending',
    error_message TEXT,
    created_at    TIMESTAMPTZ DEFAULT now(),
    completed_at  TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_pack_project ON pack(project_id);
CREATE INDEX idx_track_pack ON track(pack_id);
CREATE INDEX idx_clip_track ON clip(track_id);
CREATE INDEX idx_clip_practice_set ON clip(practice_set_id);
CREATE INDEX idx_transcript_span_track ON transcript_span(track_id);
CREATE INDEX idx_job_track ON job(track_id);
CREATE INDEX idx_job_status ON job(status);
