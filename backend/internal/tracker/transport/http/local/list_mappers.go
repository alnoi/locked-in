package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapListToOut(value models.List) tracker_genapi.ListOut {
	return tracker_genapi.ListOut{Id: value.ID, Name: value.Name, BoardID: value.BoardID, CreatedAt: value.CreatedAt, UpdatedAt: value.UpdatedAt}
}
func mapListsToOut(value models.GetListsOut) tracker_genapi.GetListsOut {
	items := make([]tracker_genapi.ListOut, 0, len(value.Items))
	for _, item := range value.Items {
		items = append(items, mapListToOut(item))
	}
	return tracker_genapi.GetListsOut{Items: items, Total: value.Total}
}
func mapCreateList(value tracker_genapi.CreateListIn) (models.CreateListIn, error) {
	in := models.CreateListIn{Name: value.Name, BoardID: value.BoardID}
	return in, models.ValidateName(in.Name)
}
func mapUpdateList(value tracker_genapi.UpdateListIn) (models.UpdateListIn, error) {
	in := models.UpdateListIn{Name: value.Name, BoardID: value.BoardID}
	if in.Name != nil {
		if err := models.ValidateName(*in.Name); err != nil {
			return in, err
		}
	}
	return in, nil
}
