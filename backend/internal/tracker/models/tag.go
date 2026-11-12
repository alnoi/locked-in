package models

import (
	"time"

	"github.com/google/uuid"
)

type Tag struct {
	ID        uuid.UUID
	OwnerID   uuid.UUID
	Name      string
	Color     *string
	CreatedAt time.Time
	UpdatedAt time.Time
}
