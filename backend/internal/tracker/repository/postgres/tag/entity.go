package tag

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	ID        uuid.UUID `db:"id"`
	OwnerID   uuid.UUID `db:"owner_id"`
	Name      string    `db:"name"`
	Color     *string   `db:"color"`
	CreatedAt time.Time `db:"created_at"`
	UpdatedAt time.Time `db:"updated_at"`
}
