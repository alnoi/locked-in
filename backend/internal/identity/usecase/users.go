package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/google/uuid"
)

type UseCase struct {
	users        usersRepository
	sessions     sessionsRepository
	boards       boardsUseCase
	transactions transactionManager
}

func New(users usersRepository, sessions sessionsRepository, boards boardsUseCase, transactions transactionManager) *UseCase {
	return &UseCase{users: users, sessions: sessions, boards: boards, transactions: transactions}
}
func (u *UseCase) GetUser(ctx context.Context, scope *uuid.UUID) (models.User, error) {
	if scope == nil {
		return models.User{}, apperr.ErrUnauthorized()
	}
	values, err := u.users.GetUsers(ctx, models.GetUsersFilters{ID: scope})
	if err != nil {
		return models.User{}, err
	}
	if len(values) == 0 {
		return models.User{}, apperr.ErrUnauthorized()
	}
	return values[0], nil
}
func (u *UseCase) UpdateProfile(ctx context.Context, scope *uuid.UUID, in *models.UpdateProfileIn) (models.User, error) {
	if scope == nil {
		return models.User{}, apperr.ErrUnauthorized()
	}
	if err := models.ValidateAvatar(in.AvatarEmoji); err != nil {
		return models.User{}, err
	}
	return u.users.UpdateProfile(ctx, scope, in)
}
