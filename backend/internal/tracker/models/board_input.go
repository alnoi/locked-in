package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateBoardIn struct {
	OwnerID         uuid.UUID
	Name            string
	ParentID        *uuid.UUID
	FilterCompleted *bool
	TagIDs          []uuid.UUID
}
type UpdateBoardIn struct {
	ID                   uuid.UUID
	Name                 *string
	ParentID             *uuid.UUID
	FilterCompleted      *bool
	TagIDs               *[]uuid.UUID
	ClearParentID        bool
	ClearFilterCompleted bool
}
type GetBoardsFilters struct {
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
	ID            *uuid.UUID
	Scope         *uuid.UUID
	Limit         *int
	Offset        *int
}
type DeleteBoardFilters struct {
	ID    *uuid.UUID
	Scope *uuid.UUID
}
