package report

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	ID        uuid.UUID `db:"id"`
	CreatedAt time.Time `db:"created_at"`
}
