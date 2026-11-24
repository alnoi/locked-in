package http

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/gin-gonic/gin"
)

type ReportHandlers struct {
	reports reportsUseCase
	actor   actorResolver
}

func New(reports reportsUseCase, actor actorResolver) *ReportHandlers {
	return &ReportHandlers{reports: reports, actor: actor}
}
func (h *ReportHandlers) CreateBugReport(c *gin.Context) {
	var request tracker_genapi.CreateBugReportIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateBugReport(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	result, err := h.reports.CreateBugReport(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapReceipt(result))
}
