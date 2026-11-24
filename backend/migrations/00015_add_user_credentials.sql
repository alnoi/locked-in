-- +goose Up
ALTER TABLE users
ADD COLUMN password_hash text;

ALTER TABLE users
ADD COLUMN avatar_emoji text NOT NULL DEFAULT '🙂';

ALTER TABLE users
ADD CONSTRAINT check_users_avatar CHECK (octet_length(avatar_emoji) BETWEEN 1 AND 128);

CREATE UNIQUE INDEX uniq_users_username_lower ON users (lower(username));

-- +goose Down
DROP INDEX uniq_users_username_lower;

ALTER TABLE users
DROP CONSTRAINT check_users_avatar;

ALTER TABLE users
DROP COLUMN avatar_emoji;

ALTER TABLE users
DROP COLUMN password_hash;
