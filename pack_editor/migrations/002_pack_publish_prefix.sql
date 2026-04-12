-- Store the S3 prefix where this pack is published (e.g. "lmaudio/starter_korean_greetings")
-- so imported bundles publish back to their original location.
ALTER TABLE pack ADD COLUMN IF NOT EXISTS publish_prefix TEXT;
