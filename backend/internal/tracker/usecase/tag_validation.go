package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) validateTags(ctx context.Context, scope *uuid.UUID, ids []uuid.UUID) error {
	if err := models.ValidateIDs(ids); err != nil {
		return err
	}
	for _, id := range ids {
		if _, err := u.GetTag(ctx, scope, id); err != nil {
			return err
		}
	}
	return nil
}
