package models

import (
	"time"

	"github.com/google/uuid"
)

type Task struct {
	ID                    uuid.UUID
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
	Completed             bool
	TagIDs                []uuid.UUID
	CreatedAt             time.Time
	UpdatedAt             time.Time
}
