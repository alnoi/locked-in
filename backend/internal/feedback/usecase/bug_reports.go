package usecase

import (
	"context"
	"errors"
	"strings"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/feedback/domain"
	"github.com/alnoi/locked-in/backend/internal/feedback/models"
)

type UseCase struct{ reports reportRepository }

func New(reports reportRepository) *UseCase { return &UseCase{reports: reports} }
func (u *UseCase) CreateBugReport(ctx context.Context, in *models.CreateBugReportIn) (models.BugReportReceipt, error) {
	in.Description = strings.TrimSpace(in.Description)
	if err := models.ValidateCreateBugReport(*in); err != nil {
		return models.BugReportReceipt{}, err
	}
	if err := domain.ValidateScreenshot(*in); err != nil {
		return models.BugReportReceipt{}, err
	}
	filters := models.GetBugReportReceiptsFilters{ID: in.ID, OwnerID: in.OwnerID}
	existing, err := u.reports.GetBugReportReceipts(ctx, filters)
	if err != nil {
		return models.BugReportReceipt{}, err
	}
	if len(existing) > 0 {
		return existing[0], nil
	}
	result, err := u.reports.CreateBugReport(ctx, in)
	var conflict *apperr.Error
	if errors.As(err, &conflict) && conflict.Code == apperr.CodeConflict {
		existing, readErr := u.reports.GetBugReportReceipts(ctx, filters)
		if readErr != nil {
			return models.BugReportReceipt{}, readErr
		}
		if len(existing) > 0 {
			return existing[0], nil
		}
	}
	return result, err
}
