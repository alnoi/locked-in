package tag

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
func (r *Repository) GetTags(ctx context.Context, filters models.GetTagsFilters) ([]models.Tag, error) {
	query, args := selectQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return nil, fmt.Errorf("GetTags: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetTags: %w", err)
	}
	return entitiesToModels(values), nil
}
func (r *Repository) GetTagsCount(ctx context.Context, filters models.GetTagsFilters) (int, error) {
	query, args := countQuery(filters)
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return 0, fmt.Errorf("GetTagsCount: %w", err)
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowTo[int])
	if err != nil {
		return 0, fmt.Errorf("GetTagsCount: %w", err)
	}
	return value, nil
}
func (r *Repository) CreateTag(ctx context.Context, in *models.CreateTagIn) (models.Tag, error) {
	args := pgx.NamedArgs{"owner_id": in.OwnerID, "name": in.Name, "color": in.Color}
	return r.write(ctx, createQuery, args)
}
func (r *Repository) UpdateTag(ctx context.Context, scope *uuid.UUID, in *models.UpdateTagIn) (models.Tag, error) {
	args := pgx.NamedArgs{"id": in.ID, "scope": scope, "name": in.Name, "color": in.Color, "clear_color": in.ClearColor}
	return r.write(ctx, updateQuery, args)
}
func (r *Repository) SoftDeleteTag(ctx context.Context, filters models.DeleteTagFilters) (int64, error) {
	if filters.ID == nil || filters.Scope == nil {
		return 0, nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, pgx.NamedArgs{"id": filters.ID, "scope": filters.Scope})
	if err != nil {
		return 0, fmt.Errorf("SoftDeleteTag: %w", apperr.HandleConstraintViolation(err))
	}
	return tag.RowsAffected(), nil
}
func (r *Repository) write(ctx context.Context, query string, args pgx.NamedArgs) (models.Tag, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, query, args)
	if err != nil {
		return models.Tag{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Tag{}, apperr.ErrNotFound()
	}
	if err != nil {
		return models.Tag{}, fmt.Errorf("write: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}
