package models

import (
	"time"

	"github.com/google/uuid"
)

type CredentialsIn struct {
	Username    string
	Password    string
	TimeZone    string
	AvatarEmoji string
}
type CreateUserIn struct {
	Username     string
	PasswordHash string
	TimeZone     string
	AvatarEmoji  string
}
type ClaimUserIn struct {
	LegacyUsername string
	CreateUserIn
}
type UserCredentials struct {
	User         User
	PasswordHash string
}
type Session struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	ExpiresAt time.Time
}
type Token struct {
	Raw  string
	Hash []byte
}
type Authentication struct {
	User        User
	AccessToken string
	ExpiresAt   time.Time
}
type AuthenticatedSession struct {
	User      User
	SessionID uuid.UUID
}
type CreateSessionIn struct {
	UserID    uuid.UUID
	TokenHash []byte
	ExpiresAt time.Time
}
type GetSessionsFilters struct{ TokenHash []byte }
type DeleteSessionsFilters struct {
	ID    uuid.UUID
	Scope *uuid.UUID
}
type UpdateProfileIn struct{ AvatarEmoji string }
