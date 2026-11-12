package models

import (
	"time"

	"github.com/google/uuid"
)

type List struct {
	ID        uuid.UUID
	OwnerID   uuid.UUID
	Name      string
	BoardID   uuid.UUID
	CreatedAt time.Time
	UpdatedAt time.Time
}
