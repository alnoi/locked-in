package postgres

import (
	"context"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) EnsureLocalUser(ctx context.Context, in *models.EnsureLocalUserIn) error {
	if _, err := r.getter.Get(ctx).Exec(ctx, ensureUserQuery, pgx.NamedArgs{"username": in.Username, "time_zone": in.TimeZone}); err != nil {
		return fmt.Errorf("EnsureLocalUser: %w", err)
	}
	return nil
}
func (r *Repository) GetUsers(ctx context.Context, in models.GetUsersFilters) ([]models.User, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, getUsersQuery, pgx.NamedArgs{"username": in.Username})
	if err != nil {
		return nil, fmt.Errorf("GetUsers: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetUsers: %w", err)
	}
	return entitiesToModels(values), nil
}
