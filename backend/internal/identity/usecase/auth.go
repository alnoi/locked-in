package usecase

import (
	"context"
	"time"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/domain"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
)

func (u *UseCase) Register(ctx context.Context, in *models.CredentialsIn) (models.Authentication, error) {
	in.Username = models.NormalizeUsername(in.Username)
	if err := models.ValidateRegistration(*in); err != nil {
		return models.Authentication{}, err
	}
	passwordHash, err := domain.HashPassword(in.Password)
	if err != nil {
		return models.Authentication{}, err
	}
	var result models.Authentication
	err = u.transactions.WithinTransaction(ctx, func(ctx context.Context) error {
		user, err := u.users.CreateUser(ctx, &models.CreateUserIn{Username: in.Username, PasswordHash: passwordHash, TimeZone: in.TimeZone, AvatarEmoji: in.AvatarEmoji})
		if err != nil {
			return err
		}
		if err := u.boards.EnsureGeneralBoard(ctx, &user.ID); err != nil {
			return err
		}
		result, err = u.createSession(ctx, user)
		return err
	})
	return result, err
}
func (u *UseCase) Login(ctx context.Context, in *models.CredentialsIn) (models.Authentication, error) {
	in.Username = models.NormalizeUsername(in.Username)
	if err := models.ValidateCredentials(*in); err != nil {
		return models.Authentication{}, apperr.ErrInvalidCredentials()
	}
	values, err := u.users.GetCredentials(ctx, models.GetUsersFilters{Username: in.Username})
	if err != nil {
		return models.Authentication{}, err
	}
	credentials := models.UserCredentials{}
	if len(values) > 0 {
		credentials = values[0]
	}
	if err := domain.VerifyPassword(credentials.PasswordHash, in.Password); err != nil {
		return models.Authentication{}, err
	}
	return u.createSession(ctx, credentials.User)
}
func (u *UseCase) Authenticate(ctx context.Context, token string) (models.AuthenticatedSession, error) {
	hash, err := domain.TokenHash(token)
	if err != nil {
		return models.AuthenticatedSession{}, err
	}
	sessions, err := u.sessions.GetSessions(ctx, models.GetSessionsFilters{TokenHash: hash})
	if err != nil {
		return models.AuthenticatedSession{}, err
	}
	if len(sessions) == 0 {
		return models.AuthenticatedSession{}, apperr.ErrUnauthorized()
	}
	user, err := u.GetUser(ctx, &sessions[0].UserID)
	if err != nil {
		return models.AuthenticatedSession{}, err
	}
	return models.AuthenticatedSession{User: user, SessionID: sessions[0].ID}, nil
}
func (u *UseCase) createSession(ctx context.Context, user models.User) (models.Authentication, error) {
	token, err := domain.NewToken()
	if err != nil {
		return models.Authentication{}, err
	}
	session, err := u.sessions.CreateSession(ctx, &models.CreateSessionIn{UserID: user.ID, TokenHash: token.Hash, ExpiresAt: time.Now().Add(30 * 24 * time.Hour)})
	if err != nil {
		return models.Authentication{}, err
	}
	return models.Authentication{User: user, AccessToken: token.Raw, ExpiresAt: session.ExpiresAt}, nil
}
func (u *UseCase) Logout(ctx context.Context, in models.DeleteSessionsFilters) error {
	_, err := u.sessions.SoftDeleteSessions(ctx, in)
	return err
}
