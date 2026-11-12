-- +goose Up
CREATE TABLE IF NOT EXISTS task_tags (
  owner_id uuid NOT NULL,
  task_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  PRIMARY KEY (owner_id, task_id, tag_id),
  CONSTRAINT fk_task_tags_parent FOREIGN KEY (owner_id, task_id) REFERENCES tasks (owner_id, id),
  CONSTRAINT fk_task_tags_tag FOREIGN KEY (owner_id, tag_id) REFERENCES tags (owner_id, id)
);

-- +goose Down
DROP TABLE IF EXISTS task_tags;
