-- +goose Up
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL CONSTRAINT uniq_users_username UNIQUE,
  time_zone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS task_tags (
  owner_id uuid NOT NULL,
  task_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  PRIMARY KEY (owner_id, task_id, tag_id),
  CONSTRAINT fk_task_tags_parent FOREIGN KEY (owner_id, task_id) REFERENCES tasks (owner_id, id),
  CONSTRAINT fk_task_tags_tag FOREIGN KEY (owner_id, tag_id) REFERENCES tags (owner_id, id)
);

CREATE TABLE IF NOT EXISTS list_tags (
  owner_id uuid NOT NULL,
  list_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  PRIMARY KEY (owner_id, list_id, tag_id),
  CONSTRAINT fk_list_tags_parent FOREIGN KEY (owner_id, list_id) REFERENCES lists (owner_id, id),
  CONSTRAINT fk_list_tags_tag FOREIGN KEY (owner_id, tag_id) REFERENCES tags (owner_id, id)
);

CREATE INDEX IF NOT EXISTS idx_tasks_list_id ON tasks (owner_id, list_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_parent_id ON tasks (owner_id, parent_id)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_planned_at ON tasks (owner_id, planned_at)
WHERE
  deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_comments_task_id ON comments (owner_id, task_id)
WHERE
  deleted_at IS NULL;

-- +goose Down
DROP TABLE IF EXISTS list_tags;

DROP TABLE IF EXISTS task_tags;

DROP TABLE IF EXISTS comments;

DROP TABLE IF EXISTS tasks;

DROP TABLE IF EXISTS tags;

DROP TABLE IF EXISTS lists;

DROP TABLE IF EXISTS users;
