package domain

import (
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func ApplyTagUpdate(value models.Tag, in *models.UpdateTagIn) (models.Tag, error) {
	if in.Name != nil {
		value.Name = *in.Name
	}
	if in.ClearColor && in.Color != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearColor {
		value.Color = nil
	} else if in.Color != nil {
		value.Color = in.Color
	}
	return value, nil
}
