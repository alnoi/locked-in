package task

import (
	"strings"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/jackc/pgx/v5"
)

func whereClause(filters models.GetTasksFilters) (string, pgx.NamedArgs) {
	conditions := []string{"t.deleted_at IS NULL"}
	if filters.MatchNone {
		conditions = append(conditions, "false")
	}
	args := pgx.NamedArgs{}
	if filters.BoardID != nil {
		conditions = append(conditions, "EXISTS(SELECT 1 FROM lists selected_list WHERE selected_list.id=t.list_id AND selected_list.owner_id=t.owner_id AND selected_list.deleted_at IS NULL AND selected_list.board_id=@board_id)")
		args["board_id"] = filters.BoardID
	}
	if filters.ID != nil {
		conditions = append(conditions, "t.id=@id")
		args["id"] = filters.ID
	}
	if filters.Scope != nil {
		conditions = append(conditions, "t.owner_id=@scope")
		args["scope"] = filters.Scope
	}
	if filters.ListID != nil {
		conditions = append(conditions, "t.list_id=@list_id")
		args["list_id"] = filters.ListID
	}
	if filters.ParentID != nil {
		conditions = append(conditions, "t.parent_id=@parent_id")
		args["parent_id"] = filters.ParentID
	}
	if filters.Completed != nil {
		conditions = append(conditions, "t.completed=@completed")
		args["completed"] = filters.Completed
	}
	if len(filters.TagIDs) > 0 {
		conditions = append(conditions, "NOT EXISTS(SELECT 1 FROM unnest(@tag_ids::uuid[]) requested(tag_id) WHERE NOT EXISTS(SELECT 1 FROM task_tags link WHERE link.task_id=t.id AND link.owner_id=t.owner_id AND link.tag_id=requested.tag_id))")
		args["tag_ids"] = filters.TagIDs
	}
	if filters.PlannedFrom != nil {
		conditions = append(conditions, "((t.duration_minutes IS NULL AND t.planned_at >= @planned_from) OR (t.planned_at + t.duration_minutes*interval '1 minute') > @planned_from)")
		args["planned_from"] = filters.PlannedFrom
	}
	if filters.PlannedTo != nil {
		conditions = append(conditions, "t.planned_at < @planned_to")
		args["planned_to"] = filters.PlannedTo
	}
	if filters.CreatedAtFrom != nil {
		conditions = append(conditions, "t.created_at >= @created_at_from")
		args["created_at_from"] = filters.CreatedAtFrom
	}
	if filters.CreatedAtTo != nil {
		conditions = append(conditions, "t.created_at < @created_at_to")
		args["created_at_to"] = filters.CreatedAtTo
	}
	return strings.Join(conditions, " AND "), args
}
func selectQuery(filters models.GetTasksFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	columns := map[string]string{"createdAt": "t.created_at", "updatedAt": "t.updated_at", "title": "t.title", "plannedAt": "t.planned_at", "deadlineAt": "t.deadline_at"}
	order := "t.created_at"
	if filters.SortBy != nil {
		if column, exists := columns[*filters.SortBy]; exists {
			order = column
		}
	}
	if filters.SortDesc != nil && *filters.SortDesc == 1 {
		order += " DESC"
	} else {
		order += " ASC"
	}
	query := "-- selectTasks\nSELECT t.is_project, t.id, t.owner_id, t.title, t.description, t.list_id, t.parent_id, t.deadline_date, t.deadline_at, t.planned_at, t.duration_minutes, t.reminder_mode, t.reminder_minutes_before, t.completed, t.created_at, t.updated_at, ARRAY(SELECT link.tag_id FROM task_tags link JOIN tags tag ON tag.id=link.tag_id AND tag.owner_id=link.owner_id AND tag.deleted_at IS NULL WHERE link.task_id=t.id AND link.owner_id=t.owner_id ORDER BY link.tag_id) AS tag_ids FROM tasks t WHERE " + where + " ORDER BY " + order + ", t.id"
	if filters.Limit != nil {
		query += " LIMIT @limit"
		args["limit"] = filters.Limit
		if filters.Offset != nil {
			query += " OFFSET @offset"
			args["offset"] = filters.Offset
		}
	}
	return query, args
}
func countQuery(filters models.GetTasksFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	return "-- countTasks\nSELECT count(*) AS total FROM tasks t WHERE " + where, args
}

const createQuery = `-- createTask
INSERT INTO
  tasks AS t (
    id,
    owner_id,
    title,
    description,
    list_id,
    is_project,
    parent_id,
    deadline_date,
    deadline_at,
    planned_at,
    duration_minutes,
    reminder_mode,
    reminder_minutes_before
  )
VALUES
  (
    COALESCE(@id::uuid, gen_random_uuid()),
    @owner_id,
    @title,
    @description,
    @list_id,
    @is_project,
    @parent_id,
    @deadline_date::text::date,
    @deadline_at,
    @planned_at,
    @duration_minutes,
    COALESCE(NULLIF(@reminder_mode, ''), 'none'),
    @reminder_minutes_before
  )
RETURNING
  t.is_project,
  t.id,
  t.owner_id,
  t.title,
  t.description,
  t.list_id,
  t.parent_id,
  t.deadline_date,
  t.deadline_at,
  t.planned_at,
  t.duration_minutes,
  t.reminder_mode,
  t.reminder_minutes_before,
  t.completed,
  t.created_at,
  t.updated_at,
  ARRAY(
    SELECT
      link.tag_id
    FROM
      task_tags link
      JOIN tags tag ON tag.id = link.tag_id
      AND tag.owner_id = link.owner_id
      AND tag.deleted_at IS NULL
    WHERE
      link.task_id = t.id
      AND link.owner_id = t.owner_id
    ORDER BY
      link.tag_id
  ) AS tag_ids`
const updateQuery = `-- updateTask
UPDATE tasks AS t
SET
  title = COALESCE(@title, t.title),
  description = CASE
    WHEN @clear_description THEN NULL
    ELSE COALESCE(@description, t.description)
  END,
  list_id = CASE
    WHEN @clear_list_id THEN NULL
    ELSE COALESCE(@list_id, t.list_id)
  END,
  is_project = COALESCE(@is_project, t.is_project),
  parent_id = CASE
    WHEN @clear_parent_id THEN NULL
    ELSE COALESCE(@parent_id, t.parent_id)
  END,
  deadline_date = CASE
    WHEN @clear_deadline_date THEN NULL
    ELSE COALESCE(@deadline_date::text::date, t.deadline_date)
  END,
  deadline_at = CASE
    WHEN @clear_deadline_at THEN NULL
    ELSE COALESCE(@deadline_at, t.deadline_at)
  END,
  planned_at = CASE
    WHEN @clear_planned_at THEN NULL
    ELSE COALESCE(@planned_at, t.planned_at)
  END,
  duration_minutes = CASE
    WHEN @clear_duration_minutes THEN NULL
    ELSE COALESCE(@duration_minutes, t.duration_minutes)
  END,
  reminder_mode = COALESCE(@reminder_mode, t.reminder_mode),
  reminder_minutes_before = COALESCE(
    @reminder_minutes_before,
    t.reminder_minutes_before
  ),
  updated_at = now()
WHERE
  t.id = @id
  AND t.owner_id = @scope
  AND t.deleted_at IS NULL
RETURNING
  t.is_project,
  t.id,
  t.owner_id,
  t.title,
  t.description,
  t.list_id,
  t.parent_id,
  t.deadline_date,
  t.deadline_at,
  t.planned_at,
  t.duration_minutes,
  t.reminder_mode,
  t.reminder_minutes_before,
  t.completed,
  t.created_at,
  t.updated_at,
  ARRAY(
    SELECT
      link.tag_id
    FROM
      task_tags link
      JOIN tags tag ON tag.id = link.tag_id
      AND tag.owner_id = link.owner_id
      AND tag.deleted_at IS NULL
    WHERE
      link.task_id = t.id
      AND link.owner_id = t.owner_id
    ORDER BY
      link.tag_id
  ) AS tag_ids`
const deleteQuery = `-- softDeleteTask
UPDATE tasks
SET
  deleted_at = now(),
  updated_at = now()
WHERE
  id = @id
  AND owner_id = @scope
  AND deleted_at IS NULL`
const completeQuery = `-- setTaskCompleted
UPDATE tasks AS t
SET
  completed = @completed,
  updated_at = now()
WHERE
  t.id = @id
  AND t.owner_id = @scope
  AND t.deleted_at IS NULL
RETURNING
  t.is_project,
  t.id,
  t.owner_id,
  t.title,
  t.description,
  t.list_id,
  t.parent_id,
  t.deadline_date,
  t.deadline_at,
  t.planned_at,
  t.duration_minutes,
  t.reminder_mode,
  t.reminder_minutes_before,
  t.completed,
  t.created_at,
  t.updated_at,
  ARRAY(
    SELECT
      link.tag_id
    FROM
      task_tags link
      JOIN tags tag ON tag.id = link.tag_id
      AND tag.owner_id = link.owner_id
      AND tag.deleted_at IS NULL
    WHERE
      link.task_id = t.id
      AND link.owner_id = t.owner_id
    ORDER BY
      link.tag_id
  ) AS tag_ids`
