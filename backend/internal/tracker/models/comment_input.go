package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateCommentIn struct {
	OwnerID uuid.UUID
	TaskID  uuid.UUID
	Text    string
}
type UpdateCommentIn struct {
	ID   uuid.UUID
	Text *string
}
type GetCommentsFilters struct {
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
	ID            *uuid.UUID
	Scope         *uuid.UUID
	TaskID        *uuid.UUID
	Limit         *int
	Offset        *int
}
type DeleteCommentFilters struct {
	ID    *uuid.UUID
	Scope *uuid.UUID
}
