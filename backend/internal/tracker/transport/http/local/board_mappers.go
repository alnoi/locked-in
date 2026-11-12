package local

import (
	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapBoardToOut(value models.Board) tracker_genapi.BoardOut {
	return tracker_genapi.BoardOut{Code: value.Code, Id: value.ID, CreatedAt: value.CreatedAt, UpdatedAt: value.UpdatedAt, Name: value.Name, ParentID: value.ParentID, FilterCompleted: value.FilterCompleted, TagIDs: value.TagIDs}
}
func mapBoardsToOut(value models.GetBoardsOut) tracker_genapi.GetBoardsOut {
	items := make([]tracker_genapi.BoardOut, 0, len(value.Items))
	for _, item := range value.Items {
		items = append(items, mapBoardToOut(item))
	}
	return tracker_genapi.GetBoardsOut{Items: items, Total: value.Total}
}
func mapCreateBoard(value tracker_genapi.CreateBoardIn) (models.CreateBoardIn, error) {
	in := models.CreateBoardIn{Name: value.Name, ParentID: value.ParentID, FilterCompleted: value.FilterCompleted, TagIDs: pointer.Get(value.TagIDs)}
	if err := models.ValidateName(in.Name); err != nil {
		return in, err
	}
	return in, nil
}
func mapUpdateBoard(value tracker_genapi.UpdateBoardIn) (models.UpdateBoardIn, error) {
	in := models.UpdateBoardIn{Name: value.Name, ParentID: value.ParentID, FilterCompleted: value.FilterCompleted, TagIDs: value.TagIDs, ClearParentID: pointer.Get(value.ClearParentID), ClearFilterCompleted: pointer.Get(value.ClearFilterCompleted)}
	if in.ClearParentID && in.ParentID != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearFilterCompleted && in.FilterCompleted != nil {
		return in, apperr.ErrValidation()
	}
	if in.Name != nil {
		if err := models.ValidateName(*in.Name); err != nil {
			return in, err
		}
	}
	return in, nil
}
