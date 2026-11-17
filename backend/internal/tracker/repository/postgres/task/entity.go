package task

import (
	"time"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"

	"github.com/google/uuid"
)

type entity struct {
	IsProject             bool                `db:"is_project"`
	ReminderMode          models.ReminderMode `db:"reminder_mode"`
	ReminderMinutesBefore int                 `db:"reminder_minutes_before"`
	ID                    uuid.UUID           `db:"id"`
	OwnerID               uuid.UUID           `db:"owner_id"`
	Title                 string              `db:"title"`
	Description           *string             `db:"description"`
	ListID                *uuid.UUID          `db:"list_id"`
	ParentID              *uuid.UUID          `db:"parent_id"`
	DeadlineDate          *time.Time          `db:"deadline_date"`
	DeadlineAt            *time.Time          `db:"deadline_at"`
	PlannedAt             *time.Time          `db:"planned_at"`
	DurationMinutes       *int                `db:"duration_minutes"`
	Completed             bool                `db:"completed"`
	CreatedAt             time.Time           `db:"created_at"`
	UpdatedAt             time.Time           `db:"updated_at"`
	TagIDs                []uuid.UUID         `db:"tag_ids"`
}
