-- +goose Up
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users (id),
  title text NOT NULL,
  description text,
  list_id uuid,
  parent_id uuid,
  deadline_date date,
  deadline_at timestamptz,
  planned_at timestamptz,
  duration_minutes bigint,
  completed boolean NOT NULL DEFAULT FALSE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT uniq_tasks_owner_id_id UNIQUE (owner_id, id),
  CONSTRAINT fk_tasks_list FOREIGN KEY (owner_id, list_id) REFERENCES lists (owner_id, id),
  CONSTRAINT fk_tasks_parent FOREIGN KEY (owner_id, parent_id) REFERENCES tasks (owner_id, id),
  CONSTRAINT check_tasks_self_parent CHECK (parent_id IS DISTINCT FROM id),
  CONSTRAINT check_tasks_deadline CHECK (
    deadline_date IS NULL
    OR deadline_at IS NULL
  ),
  CONSTRAINT check_tasks_duration CHECK (
    duration_minutes > 0
    AND duration_minutes <= 525600
  ),
  CONSTRAINT check_tasks_title CHECK (length(btrim(title)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_tasks_owner_id ON tasks (owner_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_list_id ON tasks (owner_id, list_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_parent_id ON tasks (owner_id, parent_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_planned_at ON tasks (owner_id, planned_at)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS tasks;
