package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func mapGetTasks(params tracker_genapi.GetTasksParams) (models.GetTasksFilters, error) {
	filters := models.GetTasksFilters{BoardID: params.BoardID, SortBy: params.SortBy, SortDesc: params.SortDesc, CreatedAtFrom: params.CreatedAtFrom, CreatedAtTo: params.CreatedAtTo, Limit: params.Limit, Offset: params.Offset, ListID: params.ListID, ParentID: params.ParentID, Completed: params.Completed, PlannedFrom: params.PlannedFrom, PlannedTo: params.PlannedTo}
	if filters.Limit == nil {
		filters.Offset = nil
	}
	if err := models.ValidatePagination(filters.Limit, filters.Offset); err != nil {
		return filters, err
	}
	if params.TagIDs != nil {
		filters.TagIDs = *params.TagIDs
	}
	if err := models.ValidateIDs(filters.TagIDs); err != nil {
		return filters, err
	}
	if filters.PlannedFrom != nil && filters.PlannedTo != nil && !filters.PlannedFrom.Before(*filters.PlannedTo) {
		return filters, apperr.ErrValidation()
	}
	if err := models.ValidateCollectionQuery(models.CollectionQuery{SortBy: filters.SortBy, SortDesc: filters.SortDesc, CreatedAtFrom: filters.CreatedAtFrom, CreatedAtTo: filters.CreatedAtTo}, []string{"createdAt", "updatedAt", "title", "plannedAt", "deadlineAt"}); err != nil {
		return filters, err
	}
	return filters, nil
}
