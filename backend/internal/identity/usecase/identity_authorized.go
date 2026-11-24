package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

type AuthorizedUseCase struct{ core *UseCase }

func NewAuthorized(core *UseCase) *AuthorizedUseCase { return &AuthorizedUseCase{core: core} }
func (u *AuthorizedUseCase) GetMe(ctx context.Context, actor models.Actor) (models.User, error) {
	if err := actor.Require(); err != nil {
		return models.User{}, err
	}
	return u.core.GetUser(ctx, actor.Scope())
}
func (u *AuthorizedUseCase) UpdateProfile(ctx context.Context, actor models.Actor, in *models.UpdateProfileIn) (models.User, error) {
	if err := actor.Require(); err != nil {
		return models.User{}, err
	}
	return u.core.UpdateProfile(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) Logout(ctx context.Context, actor models.Actor) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.Logout(ctx, models.DeleteSessionsFilters{ID: actor.SessionID, Scope: actor.Scope()})
}
