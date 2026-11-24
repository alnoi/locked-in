package session

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	ID        uuid.UUID `db:"id"`
	UserID    uuid.UUID `db:"user_id"`
	ExpiresAt time.Time `db:"expires_at"`
}
