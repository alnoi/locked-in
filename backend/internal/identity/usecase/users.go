package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

type UseCase struct{ repository usersRepository }

func New(repository usersRepository) *UseCase { return &UseCase{repository: repository} }
func (u *UseCase) GetLocalUser(ctx context.Context, in *models.EnsureLocalUserIn) (models.User, error) {
	if err := u.repository.EnsureLocalUser(ctx, in); err != nil {
		return models.User{}, err
	}
	values, err := u.repository.GetUsers(ctx, models.GetUsersFilters{Username: in.Username})
	if err != nil {
		return models.User{}, err
	}
	if len(values) == 0 {
		return models.User{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
