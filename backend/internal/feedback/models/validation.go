package models

import (
	"strings"
	"unicode/utf8"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/google/uuid"
)

func ValidateCreateBugReport(in CreateBugReportIn) error {
	if in.ID == uuid.Nil || strings.TrimSpace(in.Description) == "" || utf8.RuneCountInString(in.Description) > 6000 {
		return apperr.ErrValidation()
	}
	if in.Platform != "ios" && in.Platform != "macos" {
		return apperr.ErrValidation()
	}
	if in.AppVersion == "" || utf8.RuneCountInString(in.AppVersion) > 64 {
		return apperr.ErrValidation()
	}
	if len(in.Screenshot) == 0 && in.ScreenshotMime == "" {
		return nil
	}
	if len(in.Screenshot) == 0 || len(in.Screenshot) > 524288 {
		return apperr.ErrInvalidAttachment()
	}
	if in.ScreenshotMime != "image/jpeg" && in.ScreenshotMime != "image/png" {
		return apperr.ErrInvalidAttachment()
	}
	return nil
}
