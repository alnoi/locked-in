package http

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/feedback/models"
	identitymodels "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/gin-gonic/gin"
)

type reportsUseCase interface {
	CreateBugReport(context.Context, identitymodels.Actor, *models.CreateBugReportIn) (models.BugReportReceipt, error)
}
type actorResolver func(*gin.Context) identitymodels.Actor
