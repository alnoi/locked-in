package list

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	BoardID   uuid.UUID `db:"board_id"`
	ID        uuid.UUID `db:"id"`
	OwnerID   uuid.UUID `db:"owner_id"`
	Name      string    `db:"name"`
	CreatedAt time.Time `db:"created_at"`
	UpdatedAt time.Time `db:"updated_at"`
}
