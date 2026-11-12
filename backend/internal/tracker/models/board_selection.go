package models

import "github.com/google/uuid"

type BoardSelection struct {
	RootID    *uuid.UUID
	TagIDs    []uuid.UUID
	Completed *bool
	MatchNone bool
}
