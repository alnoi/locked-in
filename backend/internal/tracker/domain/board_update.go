package domain

import (
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func ApplyBoardUpdate(value models.Board, in *models.UpdateBoardIn) (models.Board, error) {
	if in.Name != nil {
		value.Name = *in.Name
	}
	if in.ClearParentID && in.ParentID != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearParentID {
		value.ParentID = nil
	} else if in.ParentID != nil {
		value.ParentID = in.ParentID
	}
	if in.ClearFilterCompleted && in.FilterCompleted != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearFilterCompleted {
		value.FilterCompleted = nil
	} else if in.FilterCompleted != nil {
		value.FilterCompleted = in.FilterCompleted
	}
	if in.TagIDs != nil {
		value.TagIDs = *in.TagIDs
	}
	return value, nil
}
