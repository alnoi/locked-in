package board

import (
	"context"
	"errors"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) GetBoards(ctx context.Context, filters models.GetBoardsFilters) ([]models.Board, error) {
	query, args := selectQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return nil, fmt.Errorf("GetBoards: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetBoards: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) GetBoardsCount(ctx context.Context, filters models.GetBoardsFilters) (int, error) {
	query, args := countQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return 0, fmt.Errorf("GetBoardsCount: %w", err)
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowTo[int])
	if err != nil {
		return 0, fmt.Errorf("GetBoardsCount: %w", err)
	}
	return value, nil
}
func (r *Repository) CreateBoard(ctx context.Context, in *models.CreateBoardIn) (models.Board, error) {
	args := pgx.NamedArgs{"owner_id": in.OwnerID, "name": in.Name, "parent_id": in.ParentID, "filter_completed": in.FilterCompleted}
	return r.write(ctx, createQuery, args)
}
func (r *Repository) UpdateBoard(ctx context.Context, scope *uuid.UUID, in *models.UpdateBoardIn) (models.Board, error) {
	args := pgx.NamedArgs{"id": in.ID, "scope": scope, "name": in.Name, "parent_id": in.ParentID, "filter_completed": in.FilterCompleted, "clear_parent_id": in.ClearParentID, "clear_filter_completed": in.ClearFilterCompleted}
	return r.write(ctx, updateQuery, args)
}
func (r *Repository) SoftDeleteBoard(ctx context.Context, filters models.DeleteBoardFilters) (int64, error) {
	if filters.ID == nil || filters.Scope == nil {
		return 0, nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": filters.ID, "scope": filters.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteBoard: %w", apperr.HandleConstraintViolation(err))
	}
	return tag.RowsAffected(), nil
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.Board, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.Board{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Board{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.Board{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}

func (r *Repository) EnsureGeneralBoard(ctx context.Context, scope *uuid.UUID) error {
	if _, err := r.getter.Get(ctx).Exec(ctx, ensureGeneralBoardQuery, pgx.NamedArgs{"scope": scope}); err != nil {
		return fmt.Errorf("EnsureGeneralBoard: %w", err)
	}
	return nil
}
