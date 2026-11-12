package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateListIn struct {
	OwnerID uuid.UUID
	Name    string
	BoardID *uuid.UUID
}
type UpdateListIn struct {
	ID      uuid.UUID
	Name    *string
	BoardID *uuid.UUID
}
type GetListsFilters struct {
	BoardID       *uuid.UUID
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
	ID            *uuid.UUID
	Scope         *uuid.UUID
	Limit         *int
	Offset        *int
}
type DeleteListFilters struct {
	ID    *uuid.UUID
	Scope *uuid.UUID
}
