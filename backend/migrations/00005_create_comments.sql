-- +goose Up
CREATE TABLE IF NOT EXISTS comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users (id),
  task_id uuid NOT NULL,
  text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uniq_comments_owner_id_id UNIQUE (owner_id, id),
  CONSTRAINT fk_comments_task FOREIGN KEY (owner_id, task_id) REFERENCES tasks (owner_id, id),
  CONSTRAINT check_comments_text CHECK (length(btrim(text)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_comments_owner_id ON comments (owner_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_comments_task_id ON comments (owner_id, task_id)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS comments;
