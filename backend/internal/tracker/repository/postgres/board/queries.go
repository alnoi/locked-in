package board

import (
	"strings"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/jackc/pgx/v5"
)

func whereClause(filters models.GetBoardsFilters) (string, pgx.NamedArgs) {
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
func selectQuery(filters models.GetBoardsFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	columns := map[string]string{"createdAt": "t.created_at", "updatedAt": "t.updated_at", "name": "t.name"}
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
	query := "-- selectBoards\nSELECT t.code, t.id, t.owner_id, t.name, t.parent_id, t.filter_completed, t.created_at, t.updated_at, ARRAY(SELECT link.tag_id FROM board_tags link JOIN tags tag ON tag.id=link.tag_id AND tag.owner_id=link.owner_id AND tag.deleted_at IS NULL WHERE link.board_id=t.id AND link.owner_id=t.owner_id ORDER BY link.tag_id) AS tag_ids FROM boards t WHERE " + where + " ORDER BY " + order + ", t.id"
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
func countQuery(filters models.GetBoardsFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	return "-- countBoards\nSELECT count(*) AS total FROM boards t WHERE " + where, args
}

const createQuery = `-- createBoard
INSERT INTO
  boards AS t (owner_id, name, parent_id, filter_completed)
VALUES
  (@owner_id, @name, @parent_id, @filter_completed)
RETURNING
  t.code,
  t.id,
  t.owner_id,
  t.name,
  t.parent_id,
  t.filter_completed,
  t.created_at,
  t.updated_at,
  ARRAY(
    SELECT
      link.tag_id
    FROM
      board_tags link
      JOIN tags tag ON tag.id = link.tag_id
      AND tag.owner_id = link.owner_id
      AND tag.deleted_at IS NULL
    WHERE
      link.board_id = t.id
      AND link.owner_id = t.owner_id
    ORDER BY
      link.tag_id
  ) AS tag_ids`
const updateQuery = `-- updateBoard
UPDATE boards AS t
SET
  name = COALESCE(@name, t.name),
  parent_id = CASE
    WHEN @clear_parent_id THEN NULL
    ELSE COALESCE(@parent_id, t.parent_id)
  END,
  filter_completed = CASE
    WHEN @clear_filter_completed THEN NULL
    ELSE COALESCE(@filter_completed, t.filter_completed)
  END,
  updated_at = now()
WHERE
  t.id = @id
  AND t.owner_id = @scope
  AND t.deleted_at IS NULL
RETURNING
  t.code,
  t.id,
  t.owner_id,
  t.name,
  t.parent_id,
  t.filter_completed,
  t.created_at,
  t.updated_at,
  ARRAY(
    SELECT
      link.tag_id
    FROM
      board_tags link
      JOIN tags tag ON tag.id = link.tag_id
      AND tag.owner_id = link.owner_id
      AND tag.deleted_at IS NULL
    WHERE
      link.board_id = t.id
      AND link.owner_id = t.owner_id
    ORDER BY
      link.tag_id
  ) AS tag_ids`
const deleteQuery = `-- softDeleteBoard
UPDATE boards
SET
  deleted_at = now(),
  updated_at = now()
WHERE
  id = @id
  AND owner_id = @scope
  AND deleted_at IS NULL`

const ensureGeneralBoardQuery = `-- ensureGeneralBoard
INSERT INTO
  boards (owner_id, name, code)
VALUES
  (@scope, 'Общая доска', 'general')
ON CONFLICT (owner_id, code) DO NOTHING`
