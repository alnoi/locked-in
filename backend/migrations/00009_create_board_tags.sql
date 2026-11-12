-- +goose Up
CREATE TABLE IF NOT EXISTS board_tags (
  owner_id uuid NOT NULL,
  board_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  PRIMARY KEY (owner_id, board_id, tag_id),
  CONSTRAINT fk_board_tags_board FOREIGN KEY (owner_id, board_id) REFERENCES boards (owner_id, id),
  CONSTRAINT fk_board_tags_tag FOREIGN KEY (owner_id, tag_id) REFERENCES tags (owner_id, id)
);

INSERT INTO
  board_tags (owner_id, board_id, tag_id)
SELECT
  links.owner_id,
  links.list_id,
  links.tag_id
FROM
  list_tags links
  JOIN boards board ON board.id = links.list_id
  AND board.owner_id = links.owner_id
ON CONFLICT (owner_id, board_id, tag_id) DO NOTHING;

-- +goose Down
DROP TABLE IF EXISTS board_tags;
