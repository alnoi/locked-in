package links

import (
	"context"
	"fmt"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) LockOwner(ctx context.Context, scope *uuid.UUID) error {
	if scope == nil {
		return apperr.ErrUnauthorized()
	}
	if _, err := r.getter.Get(ctx).Exec(ctx, lockOwnerQuery, pgx.NamedArgs{"scope": scope}); err != nil {
		return fmt.Errorf("LockOwner: %w", err)
	}
	return nil
}
func (r *Repository) SetTaskTags(ctx context.Context, in *models.SetTagsIn) error {
	return r.setTags(ctx, in, deleteTaskTagsQuery, insertTaskTagsQuery)
}
func (r *Repository) SetBoardTags(ctx context.Context, in *models.SetTagsIn) error {
	return r.setTags(ctx, in, deleteBoardTagsQuery, insertBoardTagsQuery)
}
func (r *Repository) setTags(ctx context.Context, in *models.SetTagsIn, deleteQuery, insertQuery string) error {
	args := pgx.NamedArgs{"scope": in.OwnerID, "id": in.ID, "tag_ids": in.TagIDs}
	if _, err := r.getter.Get(ctx).Exec(ctx, deleteQuery, args); err != nil {
		return fmt.Errorf("setTags: %w", err)
	}
	if len(in.TagIDs) == 0 {
		return nil
	}
	tag, err := r.getter.Get(ctx).Exec(ctx, insertQuery, args)
	if err != nil {
		return fmt.Errorf("setTags: %w", apperr.HandleConstraintViolation(err))
	}
	if tag.RowsAffected() != int64(len(in.TagIDs)) {
		return apperr.ErrConflict()
	}
	return nil
}
