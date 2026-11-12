-- +goose Up
CREATE TABLE IF NOT EXISTS list_tags (
  owner_id uuid NOT NULL,
  list_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  PRIMARY KEY (owner_id, list_id, tag_id),
  CONSTRAINT fk_list_tags_parent FOREIGN KEY (owner_id, list_id) REFERENCES lists (owner_id, id),
  CONSTRAINT fk_list_tags_tag FOREIGN KEY (owner_id, tag_id) REFERENCES tags (owner_id, id)
);

-- +goose Down
DROP TABLE IF EXISTS list_tags;
