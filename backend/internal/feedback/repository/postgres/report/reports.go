package report

import (
	"context"
	"fmt"

	"github.com/AlekSi/pointer"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/feedback/models"
	"github.com/alnoi/locked-in/backend/pkg/transaction_manager"
	"github.com/jackc/pgx/v5"
)

type Repository struct{ getter *transaction_manager.Getter }

func New(getter *transaction_manager.Getter) *Repository { return &Repository{getter: getter} }
func (r *Repository) CreateBugReport(ctx context.Context, in *models.CreateBugReportIn) (models.BugReportReceipt, error) {
	var mime *string
	if len(in.Screenshot) > 0 {
		mime = pointer.To(in.ScreenshotMime)
	}
	rows, err := r.getter.Get(ctx).Query(ctx, createQuery, pgx.NamedArgs{"id": in.ID, "owner_id": in.OwnerID, "description": in.Description, "screenshot": in.Screenshot, "screenshot_mime": mime, "platform": in.Platform, "app_version": in.AppVersion})

	if err != nil {
		return models.BugReportReceipt{}, fmt.Errorf("CreateBugReport: %w", apperr.HandleConstraintViolation(err))
	}
	value, err := pgx.CollectOneRow(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return models.BugReportReceipt{}, fmt.Errorf("CreateBugReport: %w", apperr.HandleConstraintViolation(err))
	}
	return entityToModel(value), nil
}
func (r *Repository) GetBugReportReceipts(ctx context.Context, filters models.GetBugReportReceiptsFilters) ([]models.BugReportReceipt, error) {
	rows, err := r.getter.Get(ctx).Query(ctx, selectQuery, pgx.NamedArgs{"id": filters.ID, "owner_id": filters.OwnerID})
	if err != nil {
		return nil, fmt.Errorf("GetBugReportReceipts: %w", err)
	}
	values, err := pgx.CollectRows(rows, pgx.RowToStructByNameLax[entity])
	if err != nil {
		return nil, fmt.Errorf("GetBugReportReceipts: %w", err)
	}
	return entitiesToModels(values), nil
}
