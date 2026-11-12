-- +goose Up
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS reminder_mode text NOT NULL DEFAULT 'none';

ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS reminder_minutes_before integer NOT NULL DEFAULT 0;

-- +goose StatementBegin
DO $$ BEGIN
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='tasks'::regclass AND conname='check_tasks_reminder_mode') THEN
ALTER TABLE tasks ADD CONSTRAINT check_tasks_reminder_mode CHECK(reminder_mode IN ('none','notification','alarm'));
END IF;
IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='tasks'::regclass AND conname='check_tasks_reminder_minutes_before') THEN
ALTER TABLE tasks ADD CONSTRAINT check_tasks_reminder_minutes_before CHECK(reminder_minutes_before BETWEEN 0 AND 10080);
END IF;
END $$;

-- +goose StatementEnd
-- +goose Down
ALTER TABLE tasks
DROP COLUMN IF EXISTS reminder_mode;

ALTER TABLE tasks
DROP COLUMN IF EXISTS reminder_minutes_before;
