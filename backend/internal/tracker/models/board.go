package models

import (
	"time"

	"github.com/google/uuid"
)

type Board struct {
	Code            *string
	ID              uuid.UUID
	OwnerID         uuid.UUID
	Name            string
	ParentID        *uuid.UUID
	FilterCompleted *bool
	TagIDs          []uuid.UUID
	CreatedAt       time.Time
	UpdatedAt       time.Time
}
