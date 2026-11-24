package session

const createQuery = `-- createSession
INSERT INTO
  sessions (user_id, token_hash, expires_at)
VALUES
  (@user_id, @token_hash, @expires_at)
RETURNING
  id,
  user_id,
  expires_at`
const selectQuery = `-- getSessions
SELECT
  id,
  user_id,
  expires_at
FROM
  sessions
WHERE
  token_hash = @token_hash
  AND deleted_at IS NULL
  AND expires_at > now()`
const deleteQuery = `-- softDeleteSessions
UPDATE sessions
SET
  deleted_at = now()
WHERE
  id = @id
  AND user_id = @scope
  AND deleted_at IS NULL`
