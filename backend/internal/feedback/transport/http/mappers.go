package http

import (
	"encoding/base64"

	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/feedback/models"
)

func mapCreateBugReport(value tracker_genapi.CreateBugReportIn) (models.CreateBugReportIn, error) {
	in := models.CreateBugReportIn{ID: value.Id, Description: value.Description, Platform: value.Platform, AppVersion: value.AppVersion, ScreenshotMime: pointer.Get(value.ScreenshotMime)}
	if value.ScreenshotBase64 != nil {
		if *value.ScreenshotBase64 == "" {
			return in, apperr.ErrInvalidAttachment()
		}
		screenshot, err := base64.StdEncoding.DecodeString(*value.ScreenshotBase64)
		if err != nil {
			return in, apperr.ErrInvalidAttachment()
		}
		in.Screenshot = screenshot
	}
	return in, models.ValidateCreateBugReport(in)
}
func mapReceipt(value models.BugReportReceipt) tracker_genapi.BugReportOut {
	return tracker_genapi.BugReportOut{Id: value.ID, CreatedAt: value.CreatedAt}
}
