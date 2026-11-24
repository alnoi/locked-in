package list

import (
	"strings"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/jackc/pgx/v5"
)

func whereClause(filters models.GetListsFilters) (string, pgx.NamedArgs) {
	conditions := []string{"t.deleted_at IS NULL"}
	args := pgx.NamedArgs{}
	if filters.BoardID != nil {
		conditions = append(conditions, "t.board_id=@board_id")
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
func selectQuery(filters models.GetListsFilters) (string, pgx.NamedArgs) {
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
	query := "-- selectLists\nSELECT t.id, t.owner_id, t.name, t.board_id, t.created_at, t.updated_at FROM lists t WHERE " + where + " ORDER BY " + order + ", t.id"
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
func countQuery(filters models.GetListsFilters) (string, pgx.NamedArgs) {
	where, args := whereClause(filters)
	return "-- countLists\nSELECT count(*) AS total FROM lists t WHERE " + where, args
}

const createQuery = `-- createList
INSERT INTO
  lists AS t (owner_id, name, board_id)
VALUES
  (@owner_id, @name, @board_id)
RETURNING
  t.id,
  t.owner_id,
  t.name,
  t.board_id,
  t.created_at,
  t.updated_at`
const updateQuery = `-- updateList
UPDATE lists AS t
SET
  name = COALESCE(@name, t.name),
  board_id = COALESCE(@board_id, t.board_id),
  updated_at = now()
WHERE
  t.id = @id
  AND t.owner_id = @scope
  AND t.deleted_at IS NULL
RETURNING
  t.id,
  t.owner_id,
  t.name,
  t.board_id,
  t.created_at,
  t.updated_at`
const deleteQuery = `-- softDeleteList
UPDATE lists
SET
  deleted_at = now(),
  updated_at = now()
WHERE
  id = @id
  AND owner_id = @scope
  AND deleted_at IS NULL`

const restoreQuery = `-- restoreList
UPDATE lists
SET
  deleted_at = NULL
WHERE
  id = @id
  AND owner_id = @scope`
