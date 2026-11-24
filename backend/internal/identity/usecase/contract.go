package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/google/uuid"
)

type usersRepository interface {
	GetUsers(context.Context, models.GetUsersFilters) ([]models.User, error)
	GetCredentials(context.Context, models.GetUsersFilters) ([]models.UserCredentials, error)
	CreateUser(context.Context, *models.CreateUserIn) (models.User, error)
	ClaimUser(context.Context, *models.ClaimUserIn) (models.User, error)
	UpdateProfile(context.Context, *uuid.UUID, *models.UpdateProfileIn) (models.User, error)
}
type sessionsRepository interface {
	CreateSession(context.Context, *models.CreateSessionIn) (models.Session, error)
	GetSessions(context.Context, models.GetSessionsFilters) ([]models.Session, error)
	SoftDeleteSessions(context.Context, models.DeleteSessionsFilters) (int64, error)
}
type boardsUseCase interface {
	EnsureGeneralBoard(context.Context, *uuid.UUID) error
}
type transactionManager interface {
	WithinTransaction(context.Context, func(context.Context) error) error
}
