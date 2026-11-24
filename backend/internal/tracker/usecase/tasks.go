package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetTasks(ctx context.Context, scope *uuid.UUID, filters models.GetTasksFilters) (models.GetTasksOut, error) {
	filters.Scope = scope
	if filters.ListID != nil {
		if _, err := u.GetList(ctx, scope, *filters.ListID); err != nil {
			return models.GetTasksOut{}, err
		}
	}
	if filters.BoardID != nil {
		selection, err := u.boardSelection(ctx, scope, *filters.BoardID)
		if err != nil {
			return models.GetTasksOut{}, err
		}
		filters.BoardID = selection.RootID
		filters.TagIDs = append(filters.TagIDs, selection.TagIDs...)
		filters.MatchNone = selection.MatchNone
		if filters.Completed != nil && selection.Completed != nil && *filters.Completed != *selection.Completed {
			filters.MatchNone = true
		}
		if selection.Completed != nil {
			filters.Completed = selection.Completed
		}
	}

	items, err := u.dependencies.Tasks.GetTasks(ctx, filters)
	if err != nil {
		return models.GetTasksOut{}, err
	}
	total, err := u.dependencies.Tasks.GetTasksCount(ctx, filters)
	if err != nil {
		return models.GetTasksOut{}, err
	}
	return models.GetTasksOut{Items: items, Total: total}, nil
}
func (u *UseCase) GetTask(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.Task, error) {
	values, err := u.dependencies.Tasks.GetTasks(ctx, models.GetTasksFilters{ID: &id, Scope: scope})
	if err != nil {
		return models.Task{}, err
	}
	if len(values) == 0 {
		return models.Task{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
func (u *UseCase) CreateTask(ctx context.Context, scope *uuid.UUID, in *models.CreateTaskIn) (models.Task, error) {
	var result models.Task
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		in.OwnerID = *scope
		if in.ID != nil {
			existing, err := u.dependencies.Tasks.GetTasks(ctx, models.GetTasksFilters{ID: in.ID, Scope: scope})
			if err != nil {
				return err
			}
			if len(existing) > 0 {
				result = existing[0]
				return nil
			}
		}
		if in.ParentID != nil {
			parent, err := u.GetTask(ctx, scope, *in.ParentID)
			if err != nil {
				return err
			}
			in.TagIDs = domain.InheritProjectTags(in.TagIDs, parent.TagIDs)
		}
		value := models.Task{IsProject: in.IsProject, Title: in.Title, Description: in.Description, ListID: in.ListID, ParentID: in.ParentID, DeadlineDate: in.DeadlineDate, DeadlineAt: in.DeadlineAt, PlannedAt: in.PlannedAt, DurationMinutes: in.DurationMinutes, ReminderMode: in.ReminderMode, ReminderMinutesBefore: in.ReminderMinutesBefore, TagIDs: in.TagIDs}
		if err := u.validateTask(ctx, scope, value); err != nil {
			return err
		}
		created, err := u.dependencies.Tasks.CreateTask(ctx, in)
		if err != nil {
			return err
		}
		if err := u.dependencies.Links.SetTaskTags(ctx, &models.SetTagsIn{OwnerID: *scope, ID: created.ID, TagIDs: in.TagIDs}); err != nil {
			return err
		}
		created.TagIDs = in.TagIDs
		if created.TagIDs == nil {
			created.TagIDs = []uuid.UUID{}
		}
		result = created
		return nil
	})
	return result, err
}
func (u *UseCase) UpdateTask(ctx context.Context, scope *uuid.UUID, in *models.UpdateTaskIn) (models.Task, error) {
	var result models.Task
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetTask(ctx, scope, in.ID)
		if err != nil {
			return err
		}
		value, err := domain.ApplyTaskUpdate(current, in)
		if err != nil {
			return err
		}
		if value.ParentID != nil && (current.ParentID == nil || *current.ParentID != *value.ParentID) && (in.InheritProjectTags == nil || *in.InheritProjectTags) {
			parent, err := u.GetTask(ctx, scope, *value.ParentID)
			if err != nil {
				return err
			}
			value.TagIDs = domain.InheritProjectTags(value.TagIDs, parent.TagIDs)
			in.TagIDs = &value.TagIDs
		}
		if err := u.validateTask(ctx, scope, value); err != nil {
			return err
		}
		updated, err := u.dependencies.Tasks.UpdateTask(ctx, scope, in)
		if err != nil {
			return err
		}
		if in.TagIDs != nil {
			if err := u.dependencies.Links.SetTaskTags(ctx, &models.SetTagsIn{OwnerID: *scope, ID: in.ID, TagIDs: *in.TagIDs}); err != nil {
				return err
			}
			updated.TagIDs = *in.TagIDs
		}
		result = updated
		return nil
	})
	return result, err
}
func (u *UseCase) DeleteTask(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	return u.mutate(ctx, scope, func(ctx context.Context) error {
		count, err := u.dependencies.Tasks.GetTasksCount(ctx, models.GetTasksFilters{Scope: scope, ParentID: &id})
		if err != nil {
			return err
		}
		if count > 0 {
			return apperr.ErrConflict()
		}
		affected, err := u.dependencies.Tasks.SoftDeleteTask(ctx, models.DeleteTaskFilters{ID: &id, Scope: scope})
		if err != nil {
			return err
		}
		if affected == 0 {
			return apperr.ErrNotFound()
		}
		return nil
	})
}
func (u *UseCase) validateTask(ctx context.Context, scope *uuid.UUID, value models.Task) error {
	if err := models.ValidateTask(value); err != nil {
		return err
	}
	if err := u.validateTags(ctx, scope, value.TagIDs); err != nil {
		return err
	}
	if value.ListID != nil {
		list, err := u.GetList(ctx, scope, *value.ListID)
		if err != nil {
			return err
		}
		_ = list
	}
	if value.ParentID == nil {
		return nil
	}
	parent, err := u.GetTask(ctx, scope, *value.ParentID)
	if err != nil {
		return err
	}
	related := []models.Task{parent}
	if value.ID != uuid.Nil {
		limit := 1
		children, err := u.dependencies.Tasks.GetTasks(ctx, models.GetTasksFilters{Scope: scope, ParentID: &value.ID, Limit: &limit})
		if err != nil {
			return err
		}
		related = append(related, children...)
	}
	return domain.ValidateTaskHierarchy(value, related)
}
func (u *UseCase) SetTaskCompleted(ctx context.Context, scope *uuid.UUID, in *models.SetTaskCompletedIn) (models.Task, error) {
	var result models.Task
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		var err error
		result, err = u.dependencies.Tasks.SetTaskCompleted(ctx, scope, in)
		return err
	})
	return result, err
}

func (u *UseCase) RestoreTask(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.Task, error) {
	var result models.Task
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		if err := u.dependencies.Tasks.RestoreTask(ctx, scope, id); err != nil {
			return err
		}
		value, err := u.GetTask(ctx, scope, id)
		if err != nil {
			return err
		}
		if err := u.validateTask(ctx, scope, value); err != nil {
			return err
		}
		result = value
		return nil
	})
	return result, err
}
