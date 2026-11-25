package models

import (
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/google/uuid"
)

type SetTaskOrderIn struct {
	TaskIDs        []uuid.UUID
	InitializeOnly bool
}
type CreateTaskOrderIn struct {
	OwnerID uuid.UUID
	TaskIDs []uuid.UUID
}
type UpdateTaskOrderIn struct {
	OwnerID uuid.UUID
	TaskIDs []uuid.UUID
}

func (in SetTaskOrderIn) Validate() error {
	if in.TaskIDs == nil {
		return apperr.ErrValidation()
	}
	seen := make(map[uuid.UUID]struct{}, len(in.TaskIDs))
	for _, id := range in.TaskIDs {
		if id == uuid.Nil {
			return apperr.ErrValidation()
		}
		if _, exists := seen[id]; exists {
			return apperr.ErrValidation()
		}
		seen[id] = struct{}{}
	}
	return nil
}
