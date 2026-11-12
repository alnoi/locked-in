package models

import "github.com/google/uuid"

type SetTagsIn struct {
	OwnerID uuid.UUID
	ID      uuid.UUID
	TagIDs  []uuid.UUID
}
