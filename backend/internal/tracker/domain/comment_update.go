package domain

import (
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func ApplyCommentUpdate(value models.Comment, in *models.UpdateCommentIn) (models.Comment, error) {
	if in.Text != nil {
		value.Text = *in.Text
	}
	return value, nil
}
