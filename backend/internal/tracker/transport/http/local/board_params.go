package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapGetBoards(params tracker_genapi.GetBoardsParams) (models.GetBoardsFilters, error) {
	filters := models.GetBoardsFilters{SortBy: params.SortBy, SortDesc: params.SortDesc, CreatedAtFrom: params.CreatedAtFrom, CreatedAtTo: params.CreatedAtTo, Limit: params.Limit, Offset: params.Offset}
	if filters.Limit == nil {
		filters.Offset = nil
	}
	if err := models.ValidatePagination(filters.Limit, filters.Offset); err != nil {
		return filters, err
	}
	if err := models.ValidateCollectionQuery(models.CollectionQuery{SortBy: filters.SortBy, SortDesc: filters.SortDesc, CreatedAtFrom: filters.CreatedAtFrom, CreatedAtTo: filters.CreatedAtTo}, []string{"createdAt", "updatedAt", "name"}); err != nil {
		return filters, err
	}
	return filters, nil
}
