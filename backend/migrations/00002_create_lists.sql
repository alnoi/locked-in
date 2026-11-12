-- +goose Up
CREATE TABLE IF NOT EXISTS lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users (id),
  name text NOT NULL,
  parent_id uuid,
  filter_completed boolean,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uniq_lists_owner_id_id UNIQUE (owner_id, id),
  CONSTRAINT fk_lists_parent FOREIGN KEY (owner_id, parent_id) REFERENCES lists (owner_id, id),
  CONSTRAINT check_lists_root_filter CHECK (
    parent_id IS NOT NULL
    OR filter_completed IS NULL
  ),
  CONSTRAINT check_lists_self_parent CHECK (parent_id IS DISTINCT FROM id),
  CONSTRAINT check_lists_name CHECK (length(btrim(name)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_lists_owner_id ON lists (owner_id)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS lists;
