package local

import (
	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapTagToOut(value models.Tag) tracker_genapi.TagOut {
	return tracker_genapi.TagOut{Id: value.ID, CreatedAt: value.CreatedAt, UpdatedAt: value.UpdatedAt, Name: value.Name, Color: value.Color}
}
func mapTagsToOut(value models.GetTagsOut) tracker_genapi.GetTagsOut {
	items := make([]tracker_genapi.TagOut, 0, len(value.Items))
	for _, item := range value.Items {
		items = append(items, mapTagToOut(item))
	}
	return tracker_genapi.GetTagsOut{Items: items, Total: value.Total}
}
func mapCreateTag(value tracker_genapi.CreateTagIn) (models.CreateTagIn, error) {
	in := models.CreateTagIn{Name: value.Name, Color: value.Color}
	if err := models.ValidateName(in.Name); err != nil {
		return in, err
	}
	return in, nil
}
func mapUpdateTag(value tracker_genapi.UpdateTagIn) (models.UpdateTagIn, error) {
	in := models.UpdateTagIn{Name: value.Name, Color: value.Color, ClearColor: pointer.Get(value.ClearColor)}
	if in.ClearColor && in.Color != nil {
		return in, apperr.ErrValidation()
	}
	if in.Name != nil {
		if err := models.ValidateName(*in.Name); err != nil {
			return in, err
		}
	}
	return in, nil
}
