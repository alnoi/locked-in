package models

import "github.com/google/uuid"

type SetTaskCompletedIn struct {
	ID        uuid.UUID
	Completed bool
}
