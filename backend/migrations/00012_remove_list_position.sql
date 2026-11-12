-- +goose Up
ALTER TABLE lists
DROP COLUMN IF EXISTS position;

-- +goose Down
-- +goose StatementBegin
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='lists'::regclass AND attname='position' AND NOT attisdropped) THEN
  ALTER TABLE lists ADD COLUMN position bigint NOT NULL DEFAULT 0;
  UPDATE lists SET position=ranked.position FROM (SELECT id,row_number() OVER(PARTITION BY owner_id ORDER BY created_at,id)-1 AS position FROM lists WHERE deleted_at IS NULL) ranked WHERE lists.id=ranked.id;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='lists'::regclass AND conname='check_lists_position') THEN
  ALTER TABLE lists ADD CONSTRAINT check_lists_position CHECK(position>=0);
 END IF;
END $$;

-- +goose StatementEnd
CREATE INDEX IF NOT EXISTS idx_lists_owner_id_position ON lists (owner_id, position)
WHERE
  deleted_at IS NULL;
