package session

import (
	"context"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) CreateSession(ctx context.Context, in *models.CreateSessionIn) (models.Session, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, createQuery, pgx.NamedArgs{"user_id": in.UserID, "token_hash": in.TokenHash, "expires_at": in.ExpiresAt})
	if err != nil {
		return models.Session{}, fmt.Errorf("CreateSession: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return models.Session{}, fmt.Errorf("CreateSession: %w", err)
	}
	return entityToModel(value), nil
}
func (r *Repository) GetSessions(ctx context.Context, in models.GetSessionsFilters) ([]models.Session, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, selectQuery, pgx.NamedArgs{"token_hash": in.TokenHash})
	if err != nil {
		return nil, fmt.Errorf("GetSessions: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetSessions: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) SoftDeleteSessions(ctx context.Context, in models.DeleteSessionsFilters) (int64, error) {
	if in.ID == uuid.Nil || in.Scope == nil {
		return 0, nil
	}
	result, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": in.ID, "scope": in.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteSessions: %w", err)
	}
	return result.RowsAffected(), nil
}
