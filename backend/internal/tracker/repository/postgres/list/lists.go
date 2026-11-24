package list

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
func (r *Repository) GetLists(ctx context.Context, filters models.GetListsFilters) ([]models.List, error) {
	query, args := selectQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return nil, fmt.Errorf("GetLists: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetLists: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) GetListsCount(ctx context.Context, filters models.GetListsFilters) (int, error) {
	query, args := countQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return 0, fmt.Errorf("GetListsCount: %w", err)
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowTo[int])
	if err != nil {
		return 0, fmt.Errorf("GetListsCount: %w", err)
	}
	return value, nil
}
func (r *Repository) CreateList(ctx context.Context, in *models.CreateListIn) (models.List, error) {
	args := pgx.NamedArgs{"owner_id": in.OwnerID, "name": in.Name, "board_id": in.BoardID}
	return r.write(ctx, createQuery, args)
}
func (r *Repository) UpdateList(ctx context.Context, scope *uuid.UUID, in *models.UpdateListIn) (models.List, error) {
	args := pgx.NamedArgs{"id": in.ID, "scope": scope, "name": in.Name, "board_id": in.BoardID}
	return r.write(ctx, updateQuery, args)
}
func (r *Repository) SoftDeleteList(ctx context.Context, filters models.DeleteListFilters) (int64, error) {
	if filters.ID == nil || filters.Scope == nil {
		return 0, nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": filters.ID, "scope": filters.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteList: %w", apperr.HandleConstraintViolation(err))
	}
	return tag.RowsAffected(), nil
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.List, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.List{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.List{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.List{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}

func (r *Repository) RestoreList(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	if scope == nil {
		return apperr.ErrNotFound()
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, restoreQuery, pgx.NamedArgs{"id": id, "scope": scope})
	if err != nil {
		return fmt.Errorf("RestoreList: %w", apperr.HandleConstraintViolation(err))
	}
	if tag.RowsAffected() == 0 {
		return apperr.ErrNotFound()
	}
	return nil
}
