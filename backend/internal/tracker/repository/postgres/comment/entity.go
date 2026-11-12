package comment

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	ID        uuid.UUID `db:"id"`
	OwnerID   uuid.UUID `db:"owner_id"`
	TaskID    uuid.UUID `db:"task_id"`
	Text      string    `db:"text"`
	CreatedAt time.Time `db:"created_at"`
	UpdatedAt time.Time `db:"updated_at"`
}
