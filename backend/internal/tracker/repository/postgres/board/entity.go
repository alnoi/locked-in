package board

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	Code            *string     `db:"code"`
	ID              uuid.UUID   `db:"id"`
	OwnerID         uuid.UUID   `db:"owner_id"`
	Name            string      `db:"name"`
	ParentID        *uuid.UUID  `db:"parent_id"`
	FilterCompleted *bool       `db:"filter_completed"`
	CreatedAt       time.Time   `db:"created_at"`
	UpdatedAt       time.Time   `db:"updated_at"`
	TagIDs          []uuid.UUID `db:"tag_ids"`
}
