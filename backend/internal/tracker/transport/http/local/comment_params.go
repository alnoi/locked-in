package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapGetComments(params tracker_genapi.GetCommentsParams) (models.GetCommentsFilters, error) {
	filters := models.GetCommentsFilters{SortBy: params.SortBy, SortDesc: params.SortDesc, CreatedAtFrom: params.CreatedAtFrom, CreatedAtTo: params.CreatedAtTo, Limit: params.Limit, Offset: params.Offset, TaskID: params.TaskID}
	if filters.Limit == nil {
		filters.Offset = nil
	}
	if err := models.ValidatePagination(filters.Limit, filters.Offset); err != nil {
		return filters, err
	}
	if err := models.ValidateCollectionQuery(models.CollectionQuery{SortBy: filters.SortBy, SortDesc: filters.SortDesc, CreatedAtFrom: filters.CreatedAtFrom, CreatedAtTo: filters.CreatedAtTo}, []string{"createdAt", "updatedAt"}); err != nil {
		return filters, err
	}
	return filters, nil
}
