-- +goose Up
CREATE TABLE IF NOT EXISTS task_orders (
  owner_id uuid PRIMARY KEY REFERENCES users (id),
  task_ids UUID[] NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0)
);

-- +goose Down
DROP TABLE IF EXISTS task_orders;
