package usecase

import (
	"context"

	identity "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func (u *AuthorizedUseCase) GetTaskOrder(ctx context.Context, actor identity.Actor) (models.TaskOrder, error) {
	if err := actor.Require(); err != nil {
		return models.TaskOrder{}, err
	}
	return u.core.GetTaskOrder(ctx, actor.Scope())
}
func (u *AuthorizedUseCase) SetTaskOrder(ctx context.Context, actor identity.Actor, in *models.SetTaskOrderIn) (models.TaskOrder, error) {
	if err := actor.Require(); err != nil {
		return models.TaskOrder{}, err
	}
	return u.core.SetTaskOrder(ctx, actor.Scope(), in)
}
