package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetLists(ctx context.Context, scope *uuid.UUID, filters models.GetListsFilters) (models.GetListsOut, error) {
	filters.Scope = scope
	if filters.BoardID != nil {
		selection, err := u.boardSelection(ctx, scope, *filters.BoardID)
		if err != nil {
			return models.GetListsOut{}, err
		}
		filters.BoardID = selection.RootID
	}
	items, err := u.dependencies.Lists.GetLists(ctx, filters)
	if err != nil {
		return models.GetListsOut{}, err
	}
	total, err := u.dependencies.Lists.GetListsCount(ctx, filters)
	if err != nil {
		return models.GetListsOut{}, err
	}
	return models.GetListsOut{Items: items, Total: total}, nil
}
func (u *UseCase) GetList(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.List, error) {
	values, err := u.dependencies.Lists.GetLists(ctx, models.GetListsFilters{ID: &id, Scope: scope})
	if err != nil {
		return models.List{}, err
	}
	if len(values) == 0 {
		return models.List{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
func (u *UseCase) CreateList(ctx context.Context, scope *uuid.UUID, in *models.CreateListIn) (models.List, error) {
	var result models.List
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		in.OwnerID = *scope
		if in.BoardID == nil {
			general, err := u.generalBoard(ctx, scope)
			if err != nil {
				return err
			}
			in.BoardID = &general.ID
		}
		if err := u.validateList(ctx, scope, models.List{Name: in.Name, BoardID: *in.BoardID}); err != nil {
			return err
		}
		var err error
		result, err = u.dependencies.Lists.CreateList(ctx, in)
		return err
	})
	return result, err
}
func (u *UseCase) UpdateList(ctx context.Context, scope *uuid.UUID, in *models.UpdateListIn) (models.List, error) {
	var result models.List
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetList(ctx, scope, in.ID)
		if err != nil {
			return err
		}
		value, err := domain.ApplyListUpdate(current, in)
		if err != nil {
			return err
		}
		if err := u.validateList(ctx, scope, value); err != nil {
			return err
		}
		result, err = u.dependencies.Lists.UpdateList(ctx, scope, in)
		return err
	})
	return result, err
}
func (u *UseCase) DeleteList(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	return u.mutate(ctx, scope, func(ctx context.Context) error {
		tasks, err := u.dependencies.Tasks.GetTasks(ctx, models.GetTasksFilters{Scope: scope, ListID: &id})
		if err != nil {
			return err
		}
		for _, task := range tasks {
			if _, err := u.dependencies.Tasks.UpdateTask(ctx, scope, &models.UpdateTaskIn{ID: task.ID, ClearListID: true}); err != nil {
				return err
			}
		}
		affected, err := u.dependencies.Lists.SoftDeleteList(ctx, models.DeleteListFilters{ID: &id, Scope: scope})
		if err != nil {
			return err
		}
		if affected == 0 {
			return apperr.ErrNotFound()
		}
		return nil
	})
}
func (u *UseCase) validateList(ctx context.Context, scope *uuid.UUID, value models.List) error {
	if err := models.ValidateName(value.Name); err != nil {
		return err
	}
	board, err := u.GetBoard(ctx, scope, value.BoardID)
	if err != nil {
		return err
	}
	if board.ParentID != nil {
		return apperr.ErrValidation()
	}
	return nil
}

func (u *UseCase) RestoreList(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.List, error) {
	var result models.List
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		if err := u.dependencies.Lists.RestoreList(ctx, scope, id); err != nil {
			return err
		}
		value, err := u.GetList(ctx, scope, id)
		if err != nil {
			return err
		}
		if err := u.validateList(ctx, scope, value); err != nil {
			return err
		}
		result = value
		return nil
	})
	return result, err
}
