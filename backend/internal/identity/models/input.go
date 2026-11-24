package models

import "github.com/google/uuid"

type EnsureLocalUserIn struct {
	Username string
	TimeZone string
}
type GetUsersFilters struct {
	Username string
	ID       *uuid.UUID
}
