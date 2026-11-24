package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/feedback/models"
)

type reportRepository interface {
	CreateBugReport(context.Context, *models.CreateBugReportIn) (models.BugReportReceipt, error)
	GetBugReportReceipts(context.Context, models.GetBugReportReceiptsFilters) ([]models.BugReportReceipt, error)
}
