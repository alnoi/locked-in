-- +goose Up
ALTER TABLE lists
ADD COLUMN IF NOT EXISTS board_id uuid;

ALTER TABLE lists
ADD COLUMN IF NOT EXISTS migrated_to_board boolean NOT NULL DEFAULT FALSE;

UPDATE lists
SET
  board_id = general.id
FROM
  boards general
WHERE
  general.owner_id = lists.owner_id
  AND general.code = 'general'
  AND lists.board_id IS NULL;

-- +goose StatementBegin
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='lists'::regclass AND conname='fk_lists_board') THEN
 ALTER TABLE lists ADD CONSTRAINT fk_lists_board FOREIGN KEY(owner_id,board_id) REFERENCES boards(owner_id,id);
 END IF;
END $$;

-- +goose StatementEnd
ALTER TABLE lists
ALTER COLUMN board_id
SET NOT NULL;

UPDATE lists
SET
  deleted_at = now(),
  migrated_to_board = TRUE
WHERE
  parent_id IS NOT NULL
  AND deleted_at IS NULL;

-- +goose Down
UPDATE lists
SET
  deleted_at = NULL
WHERE
  migrated_to_board = TRUE;

ALTER TABLE lists
DROP COLUMN IF EXISTS migrated_to_board;

ALTER TABLE lists
DROP COLUMN IF EXISTS board_id;
