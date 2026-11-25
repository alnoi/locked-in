package task_order

import (
	"context"
	"errors"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) GetTaskOrders(ctx context.Context, filters models.GetTaskOrdersFilters) ([]models.TaskOrder, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, selectQuery, pgx.NamedArgs{"scope": filters.Scope})
	if err != nil {
		return nil, fmt.Errorf("GetTaskOrders: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetTaskOrders: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) CreateTaskOrder(ctx context.Context, in *models.CreateTaskOrderIn) (models.TaskOrder, error) {
	return r.write(ctx, createQuery, pgx.NamedArgs{"owner_id": in.OwnerID, "task_ids": in.TaskIDs})
}
func (r *Repository) UpdateTaskOrder(ctx context.Context, in *models.UpdateTaskOrderIn) (models.TaskOrder, error) {
	return r.write(ctx, updateQuery, pgx.NamedArgs{"owner_id": in.OwnerID, "task_ids": in.TaskIDs})
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.TaskOrder, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.TaskOrder{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.TaskOrder{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.TaskOrder{}, fmt.Errorf("write: %w", err)
	}
	return entityToModel(value), nil
}
