package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (r *Repository) GetCredentials(ctx context.Context, in models.GetUsersFilters) ([]models.UserCredentials, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, credentialsQuery, pgx.NamedArgs{"username": in.Username})
	if err != nil {
		return nil, fmt.Errorf("GetCredentials: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[credentialsEntity])
	if err != nil {
		return nil, fmt.Errorf("GetCredentials: %w", err)
	}
	return credentialsToModels(values), nil
}
func (r *Repository) CreateUser(ctx context.Context, in *models.CreateUserIn) (models.User, error) {
	return r.write(ctx, createUserQuery, pgx.NamedArgs{"username": in.Username, "password_hash": in.PasswordHash, "time_zone": in.TimeZone, "avatar_emoji": in.AvatarEmoji})
}
func (r *Repository) ClaimUser(ctx context.Context, in *models.ClaimUserIn) (models.User, error) {
	return r.write(ctx, claimUserQuery, pgx.NamedArgs{"legacy_username": in.LegacyUsername, "username": in.Username, "password_hash": in.PasswordHash, "time_zone": in.TimeZone, "avatar_emoji": in.AvatarEmoji})
}
func (r *Repository) UpdateProfile(ctx context.Context, scope *uuid.UUID, in *models.UpdateProfileIn) (models.User, error) {
	return r.write(ctx, profileQuery, pgx.NamedArgs{"scope": scope, "avatar_emoji": in.AvatarEmoji})
}
func (r *Repository) write(ctx context.Context, query string, arguments pgx.NamedArgs) (models.User, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, arguments)
	if err != nil {
		return models.User{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.User{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.User{}, fmt.Errorf("write: %w", err)
	}
	return entityToModel(value), nil
}
