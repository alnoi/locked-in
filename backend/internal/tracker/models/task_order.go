package models

import "github.com/google/uuid"

type TaskOrder struct {
	TaskIDs  []uuid.UUID
	Revision int64
}
type GetTaskOrdersFilters struct{ Scope *uuid.UUID }
