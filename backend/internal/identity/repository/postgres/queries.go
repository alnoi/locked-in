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
  created_at
FROM
  users
WHERE
  username = @username`
