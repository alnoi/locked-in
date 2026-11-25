package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetTaskOrder(ctx context.Context, scope *uuid.UUID) (models.TaskOrder, error) {
	orders, err := u.dependencies.TaskOrders.GetTaskOrders(ctx, models.GetTaskOrdersFilters{Scope: scope})
	if err != nil {
		return models.TaskOrder{}, err
	}
	result := models.TaskOrder{}
	if len(orders) > 0 {
		result = orders[0]
	}
	tasks, err := u.dependencies.Tasks.GetTasks(ctx, models.GetTasksFilters{Scope: scope})
	if err != nil {
		return models.TaskOrder{}, err
	}
	result.TaskIDs = domain.NormalizeTaskOrder(tasks, result.TaskIDs)
	return result, nil
}
func (u *UseCase) SetTaskOrder(ctx context.Context, scope *uuid.UUID, in *models.SetTaskOrderIn) (models.TaskOrder, error) {
	var result models.TaskOrder
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetTaskOrder(ctx, scope)
		if err != nil {
			return err
		}
		if in.InitializeOnly && current.Revision > 0 {
			result = current
			return nil
		}
		ids, err := domain.MergeTaskOrder(current.TaskIDs, in.TaskIDs)
		if err != nil {
			return err
		}
		if current.Revision == 0 {
			result, err = u.dependencies.TaskOrders.CreateTaskOrder(ctx, &models.CreateTaskOrderIn{OwnerID: *scope, TaskIDs: ids})
		} else {
			result, err = u.dependencies.TaskOrders.UpdateTaskOrder(ctx, &models.UpdateTaskOrderIn{OwnerID: *scope, TaskIDs: ids})
		}
		return err
	})
	return result, err
}
