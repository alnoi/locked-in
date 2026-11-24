package postgres

const ensureUserQuery = `-- ensureLocalUser
INSERT INTO
  users (username, time_zone)
VALUES
  (@username, @time_zone)
ON CONFLICT (username) DO NOTHING`
const getUsersQuery = `-- getUsers
SELECT
  id,
  username,
  time_zone,
  avatar_emoji,
  created_at
FROM
  users
WHERE
  (
    @username = ''
    OR username = @username
  )
  AND (
    @id::uuid IS NULL
    OR id = @id
  )`
const credentialsQuery = `-- getCredentials
SELECT
  id,
  username,
  time_zone,
  avatar_emoji,
  created_at,
  password_hash
FROM
  users
WHERE
  username = @username
  AND password_hash IS NOT NULL`
const createUserQuery = `-- createUser
INSERT INTO
  users (username, password_hash, time_zone, avatar_emoji)
VALUES
  (
    @username,
    @password_hash,
    @time_zone,
    @avatar_emoji
  )
RETURNING
  id,
  username,
  time_zone,
  avatar_emoji,
  created_at`
const claimUserQuery = `-- claimUser
UPDATE users
SET
  username = @username,
  password_hash = @password_hash,
  time_zone = @time_zone,
  avatar_emoji = @avatar_emoji
WHERE
  username = @legacy_username
  AND password_hash IS NULL
RETURNING
  id,
  username,
  time_zone,
  avatar_emoji,
  created_at`
const profileQuery = `-- updateProfile
UPDATE users
SET
  avatar_emoji = @avatar_emoji
WHERE
  id = @scope
RETURNING
  id,
  username,
  time_zone,
  avatar_emoji,
  created_at`
