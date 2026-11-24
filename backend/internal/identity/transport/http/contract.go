package http

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

type authenticationUseCase interface {
	Register(context.Context, *models.CredentialsIn) (models.Authentication, error)
	Login(context.Context, *models.CredentialsIn) (models.Authentication, error)
	Authenticate(context.Context, string) (models.AuthenticatedSession, error)
}
type profileUseCase interface {
	GetMe(context.Context, models.Actor) (models.User, error)
	UpdateProfile(context.Context, models.Actor, *models.UpdateProfileIn) (models.User, error)
	Logout(context.Context, models.Actor) error
}
