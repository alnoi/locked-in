-- +goose Up
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL CONSTRAINT uniq_users_username UNIQUE,
  time_zone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS users;
