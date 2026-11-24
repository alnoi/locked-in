package models

import (
	"time"

	"github.com/google/uuid"
)

type CreateTaskIn struct {
	IsProject             bool
	ID                    *uuid.UUID
	OwnerID               uuid.UUID
	Title                 string
	Description           *string
	ListID                *uuid.UUID
	ParentID              *uuid.UUID
	DeadlineDate          *string
	DeadlineAt            *time.Time
	PlannedAt             *time.Time
	DurationMinutes       *int
	ReminderMode          ReminderMode
	ReminderMinutesBefore int
	TagIDs                []uuid.UUID
}
type UpdateTaskIn struct {
	InheritProjectTags    *bool
	IsProject             *bool
	ID                    uuid.UUID
	Title                 *string
	Description           *string
	ListID                *uuid.UUID
	ParentID              *uuid.UUID
	DeadlineDate          *string
	DeadlineAt            *time.Time
	PlannedAt             *time.Time
	DurationMinutes       *int
	ReminderMode          *ReminderMode
	ReminderMinutesBefore *int
	TagIDs                *[]uuid.UUID
	ClearDescription      bool
	ClearListID           bool
	ClearParentID         bool
	ClearDeadlineDate     bool
	ClearDeadlineAt       bool
	ClearPlannedAt        bool
	ClearDurationMinutes  bool
}
type GetTasksFilters struct {
	BoardID       *uuid.UUID
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
	MatchNone     bool
	ID            *uuid.UUID
	Scope         *uuid.UUID
	ListID        *uuid.UUID
	ParentID      *uuid.UUID
	Completed     *bool
	TagIDs        []uuid.UUID
	PlannedFrom   *time.Time
	PlannedTo     *time.Time
	Limit         *int
	Offset        *int
}
type DeleteTaskFilters struct {
	ID    *uuid.UUID
	Scope *uuid.UUID
}
