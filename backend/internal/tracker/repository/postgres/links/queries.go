package links

const lockOwnerQuery = `-- lockOwner
SELECT
  pg_advisory_xact_lock(hashtextextended (@scope::text, 0))`
const deleteTaskTagsQuery = `-- deleteTaskTags
DELETE FROM task_tags
WHERE
  owner_id = @scope
  AND task_id = @id`
const insertTaskTagsQuery = `-- insertTaskTags
INSERT INTO
  task_tags (owner_id, task_id, tag_id)
SELECT
  @scope,
  @id,
  tag_id
FROM
  unnest(@tag_ids::UUID[]) selected (tag_id)`
const deleteBoardTagsQuery = `-- deleteBoardTags
DELETE FROM board_tags
WHERE
  owner_id = @scope
  AND board_id = @id`
const insertBoardTagsQuery = `-- insertBoardTags
INSERT INTO
  board_tags (owner_id, board_id, tag_id)
SELECT
  @scope,
  @id,
  tag_id
FROM
  unnest(@tag_ids::UUID[]) selected (tag_id)`
