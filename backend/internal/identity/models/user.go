package models

import (
	"time"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/google/uuid"
)

type User struct {
	ID        uuid.UUID
	Username  string
	TimeZone  string
	CreatedAt time.Time
}
type Actor struct{ UserID uuid.UUID }

func (a Actor) Require() error {
	if a.UserID == uuid.Nil {
		return apperr.ErrUnauthorized()
	}
	return nil
}
func (a Actor) Scope() *uuid.UUID { return &a.UserID }
