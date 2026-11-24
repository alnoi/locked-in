-- +goose Up
CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users (id),
  token_hash bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX idx_sessions_user_id ON sessions (user_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX idx_sessions_expires_at ON sessions (expires_at)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE sessions;
