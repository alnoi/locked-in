package comment

import (
	"strings"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/jackc/pgx/v5"
)

func whereClause(filters models.GetCommentsFilters) (string, pgx.NamedArgs) {
	conditions := []string{"t.deleted_at IS NULL"}
	args := pgx.NamedArgs{}
	if filters.ID != nil {
		conditions = append(conditions, "t.id=@id")
		args["id"] = filters.ID
	}
	if filters.Scope != nil {
		conditions = append(conditions, "t.owner_id=@scope")
		args["scope"] = filters.Scope
	}
	conditions = append(conditions, "EXISTS(SELECT 1 FROM tasks parent WHERE parent.id=t.task_id AND parent.owner_id=t.owner_id AND parent.deleted_at IS NULL)")
	if filters.TaskID != nil {
		conditions = append(conditions, "t.task_id=@task_id")
		args["task_id"] = filters.TaskID
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
func selectQuery(filters models.GetCommentsFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	columns := map[string]string{"createdAt": "t.created_at", "updatedAt": "t.updated_at"}
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
	query := "-- selectComments\nSELECT t.id, t.owner_id, t.task_id, t.text, t.created_at, t.updated_at FROM comments t WHERE " + where + " ORDER BY " + order + ", t.id"
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
func countQuery(filters models.GetCommentsFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	return "-- countComments\nSELECT count(*) AS total FROM comments t WHERE " + where, args
}

const createQuery = `-- createComment
INSERT INTO
  comments AS t (owner_id, task_id, text)
VALUES
  (@owner_id, @task_id, @text)
RETURNING
  t.id,
  t.owner_id,
  t.task_id,
  t.text,
  t.created_at,
  t.updated_at`
const updateQuery = `-- updateComment
UPDATE comments AS t
SET
  text = COALESCE(@text, t.text),
  updated_at = now()
WHERE
  t.id = @id
  AND t.owner_id = @scope
  AND t.deleted_at IS NULL
RETURNING
  t.id,
  t.owner_id,
  t.task_id,
  t.text,
  t.created_at,
  t.updated_at`
const deleteQuery = `-- softDeleteComment
UPDATE comments
SET
  deleted_at = now(),
  updated_at = now()
WHERE
  id = @id
  AND owner_id = @scope
  AND deleted_at IS NULL`
