package models

import (
	"time"

	"github.com/google/uuid"
)

type Comment struct {
	ID        uuid.UUID
	OwnerID   uuid.UUID
	TaskID    uuid.UUID
	Text      string
	CreatedAt time.Time
	UpdatedAt time.Time
}
