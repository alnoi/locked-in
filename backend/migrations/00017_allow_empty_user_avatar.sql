-- +goose Up
ALTER TABLE users
ALTER COLUMN avatar_emoji
SET DEFAULT '';

ALTER TABLE users
DROP CONSTRAINT check_users_avatar;

ALTER TABLE users
ADD CONSTRAINT check_users_avatar CHECK (octet_length(avatar_emoji) BETWEEN 0 AND 128);

-- +goose Down
UPDATE users
SET
  avatar_emoji = '🙂'
WHERE
  avatar_emoji = '';

ALTER TABLE users
ALTER COLUMN avatar_emoji
SET DEFAULT '🙂';

ALTER TABLE users
DROP CONSTRAINT check_users_avatar;

ALTER TABLE users
ADD CONSTRAINT check_users_avatar CHECK (octet_length(avatar_emoji) BETWEEN 1 AND 128);
