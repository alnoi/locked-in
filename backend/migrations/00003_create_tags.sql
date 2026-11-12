-- +goose Up
CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users (id),
  name text NOT NULL,
  color text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uniq_tags_owner_id_id UNIQUE (owner_id, id),
  CONSTRAINT check_tags_name CHECK (length(btrim(name)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_tags_owner_id ON tags (owner_id)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS tags;
