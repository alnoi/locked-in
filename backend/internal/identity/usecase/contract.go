package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

type usersRepository interface {
	EnsureLocalUser(context.Context, *models.EnsureLocalUserIn) error
	GetUsers(context.Context, models.GetUsersFilters) ([]models.User, error)
}
