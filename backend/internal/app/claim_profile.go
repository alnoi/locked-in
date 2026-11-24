package app

import (
	"context"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/config"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
	identityrepo "github.com/alnoi/locked-in/backend/internal/identity/repository/postgres"
	sessionrepo "github.com/alnoi/locked-in/backend/internal/identity/repository/postgres/session"
	identityusecase "github.com/alnoi/locked-in/backend/internal/identity/usecase"
	boardrepo "github.com/alnoi/locked-in/backend/internal/tracker/repository/postgres/board"
	trackerusecase "github.com/alnoi/locked-in/backend/internal/tracker/usecase"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
)

func ClaimLegacyProfile(ctx context.Context, settings config.Config, in *models.CredentialsIn) (models.User, error) {
	pool, err := openDatabase(ctx, settings.Postgres)
	if err != nil {
		return models.User{}, err
	}
	defer pool.Close()
	if err := migrate(ctx, pool, settings.MigrationsPath); err != nil {
		return models.User{}, fmt.Errorf("ClaimLegacyProfile: %w", err)
	}
	getter := transaction_manager.NewGetter(pool)
	transactions := transaction_manager.NewManager(pool)
	users := identityrepo.New(getter)
	sessions := sessionrepo.New(getter)
	boards := boardrepo.New(getter)
	tracker := trackerusecase.New(trackerusecase.Dependencies{Boards: boards})
	identity := identityusecase.New(users, sessions, tracker, transactions)
	return identity.ClaimLegacyProfile(ctx, settings.LocalUser.Username, in)
}
