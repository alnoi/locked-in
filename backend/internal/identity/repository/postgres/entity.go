package postgres

import (
	"time"

	"github.com/google/uuid"
)

type entity struct {
	ID          uuid.UUID `db:"id"`
	AvatarEmoji string    `db:"avatar_emoji"`
	Username    string    `db:"username"`
	TimeZone    string    `db:"time_zone"`
	CreatedAt   time.Time `db:"created_at"`
}

type credentialsEntity struct {
	entity
	PasswordHash string `db:"password_hash"`
}
