package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateTagIn struct {
	OwnerID uuid.UUID
	Name    string
	Color   *string
}
type UpdateTagIn struct {
	ID         uuid.UUID
	Name       *string
	Color      *string
	ClearColor bool
}
type GetTagsFilters struct {
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
	ID            *uuid.UUID
	Scope         *uuid.UUID
	Limit         *int
	Offset        *int
}
type DeleteTagFilters struct {
	ID    *uuid.UUID
	Scope *uuid.UUID
}
