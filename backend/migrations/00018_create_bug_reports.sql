-- +goose Up
CREATE TABLE IF NOT EXISTS bug_reports (
  id uuid PRIMARY KEY,
  owner_id uuid REFERENCES users (id),
  description text NOT NULL CHECK (
    char_length(btrim(description)) BETWEEN 1 AND 6000
  ),
  screenshot bytea CHECK (octet_length(screenshot) BETWEEN 1 AND 524288),
  screenshot_mime text,
  platform text NOT NULL CHECK (platform IN ('ios', 'macos')),
  app_version text NOT NULL CHECK (char_length(app_version) BETWEEN 1 AND 64),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT check_bug_reports_screenshot CHECK (
    (
      screenshot IS NULL
      AND screenshot_mime IS NULL
    )
    OR (
      screenshot IS NOT NULL
      AND screenshot_mime IS NOT NULL
      AND screenshot_mime IN ('image/jpeg', 'image/png')
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON bug_reports (created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS bug_reports;
