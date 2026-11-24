package domain

import (
	"bytes"
	"image"
	"image/jpeg"
	"image/png"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/feedback/models"
)

func ValidateScreenshot(in models.CreateBugReportIn) error {
	if len(in.Screenshot) == 0 {
		return nil
	}
	var config image.Config
	var err error
	switch in.ScreenshotMime {
	case "image/jpeg":
		config, err = jpeg.DecodeConfig(bytes.NewReader(in.Screenshot))
	case "image/png":
		config, err = png.DecodeConfig(bytes.NewReader(in.Screenshot))
	default:
		return apperr.ErrInvalidAttachment()
	}
	if err != nil || config.Width <= 0 || config.Height <= 0 || int64(config.Width)*int64(config.Height) > 20000000 {
		return apperr.ErrInvalidAttachment()
	}
	switch in.ScreenshotMime {
	case "image/jpeg":
		_, err = jpeg.Decode(bytes.NewReader(in.Screenshot))
	case "image/png":
		_, err = png.Decode(bytes.NewReader(in.Screenshot))
	}
	if err != nil {
		return apperr.ErrInvalidAttachment()
	}
	return nil
}
