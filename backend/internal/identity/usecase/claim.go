package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/domain"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

func (u *UseCase) ClaimLegacyProfile(ctx context.Context, legacyUsername string, in *models.CredentialsIn) (models.User, error) {
	in.Username = models.NormalizeUsername(in.Username)
	if err := models.ValidateRegistration(*in); err != nil {
		return models.User{}, err
	}
	legacy, err := u.users.GetUsers(ctx, models.GetUsersFilters{Username: legacyUsername})
	if err != nil {
		return models.User{}, err
	}
	if len(legacy) == 0 {
		existing, err := u.users.GetCredentials(ctx, models.GetUsersFilters{Username: in.Username})
		if err != nil {
			return models.User{}, err
		}
		if len(existing) == 0 {
			return models.User{}, apperr.ErrNotFound()
		}
		if err := domain.VerifyPassword(existing[0].PasswordHash, in.Password); err != nil {
			return models.User{}, err
		}
		return existing[0].User, nil
	}
	passwordHash, err := domain.HashPassword(in.Password)
	if err != nil {
		return models.User{}, err
	}
	var result models.User
	err = u.transactions.WithinTransaction(ctx, func(ctx context.Context) error {
		value, err := u.users.ClaimUser(ctx, &models.ClaimUserIn{LegacyUsername: legacyUsername,
			CreateUserIn: models.CreateUserIn{Username: in.Username, PasswordHash: passwordHash, TimeZone: in.TimeZone, AvatarEmoji: in.AvatarEmoji}})
		if err != nil {
			return err
		}
		if err := u.boards.EnsureGeneralBoard(ctx, &value.ID); err != nil {
			return err
		}
		result = value
		return nil
	})
	return result, err
}
