package comment

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
func (r *Repository) GetComments(ctx context.Context, filters models.GetCommentsFilters) ([]models.Comment, error) {
	query, args := selectQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return nil, fmt.Errorf("GetComments: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetComments: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) GetCommentsCount(ctx context.Context, filters models.GetCommentsFilters) (int, error) {
	query, args := countQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return 0, fmt.Errorf("GetCommentsCount: %w", err)
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowTo[int])
	if err != nil {
		return 0, fmt.Errorf("GetCommentsCount: %w", err)
	}
	return value, nil
}
func (r *Repository) CreateComment(ctx context.Context, in *models.CreateCommentIn) (models.Comment, error) {
	args := pgx.NamedArgs{"owner_id": in.OwnerID, "task_id": in.TaskID, "text": in.Text}
	return r.write(ctx, createQuery, args)
}
func (r *Repository) UpdateComment(ctx context.Context, scope *uuid.UUID, in *models.UpdateCommentIn) (models.Comment, error) {
	args := pgx.NamedArgs{"id": in.ID, "scope": scope, "text": in.Text}
	return r.write(ctx, updateQuery, args)
}
func (r *Repository) SoftDeleteComment(ctx context.Context, filters models.DeleteCommentFilters) (int64, error) {
	if filters.ID == nil || filters.Scope == nil {
		return 0, nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": filters.ID, "scope": filters.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteComment: %w", apperr.HandleConstraintViolation(err))
	}
	return tag.RowsAffected(), nil
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.Comment, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.Comment{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Comment{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.Comment{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}
