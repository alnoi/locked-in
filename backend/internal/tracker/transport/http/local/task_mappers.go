package local

import (
	"github.com/AlekSi/pointer"
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func mapTaskToOut(value models.Task) tracker_genapi.TaskOut {
	return tracker_genapi.TaskOut{IsProject: value.IsProject, Id: value.ID, CreatedAt: value.CreatedAt, UpdatedAt: value.UpdatedAt, Title: value.Title, Description: value.Description, ListID: value.ListID, ParentID: value.ParentID, DeadlineDate: value.DeadlineDate, DeadlineAt: value.DeadlineAt, PlannedAt: value.PlannedAt, DurationMinutes: value.DurationMinutes, ReminderMode: string(value.ReminderMode), ReminderMinutesBefore: value.ReminderMinutesBefore, TagIDs: value.TagIDs, Completed: value.Completed}
}
func mapTasksToOut(value models.GetTasksOut) tracker_genapi.GetTasksOut {
	items := make([]tracker_genapi.TaskOut, 0, len(value.Items))
	for _, item := range value.Items {
		items = append(items, mapTaskToOut(item))
	}
	return tracker_genapi.GetTasksOut{Items: items, Total: value.Total}
}
func mapCreateTask(value tracker_genapi.CreateTaskIn) (models.CreateTaskIn, error) {
	if value.ID != nil && pointer.Get(value.ID) == uuid.Nil {
		return models.CreateTaskIn{}, apperr.ErrValidation()
	}
	mode, err := models.ParseReminderMode(pointer.Get(value.ReminderMode))
	if err != nil {
		return models.CreateTaskIn{}, err
	}

	in := models.CreateTaskIn{IsProject: pointer.Get(value.IsProject), ID: value.ID, Title: value.Title, Description: value.Description, ListID: value.ListID, ParentID: value.ParentID, DeadlineDate: value.DeadlineDate, DeadlineAt: value.DeadlineAt, PlannedAt: value.PlannedAt, DurationMinutes: value.DurationMinutes, ReminderMode: mode, ReminderMinutesBefore: pointer.Get(value.ReminderMinutesBefore), TagIDs: pointer.Get(value.TagIDs)}
	if err := models.ValidateTask(models.Task{Title: in.Title, DeadlineDate: in.DeadlineDate, DeadlineAt: in.DeadlineAt}); err != nil {
		return in, err
	}
	return in, nil
}
func mapUpdateTask(value tracker_genapi.UpdateTaskIn) (models.UpdateTaskIn, error) {
	var mode *models.ReminderMode
	if value.ReminderMode != nil {
		parsed, err := models.ParseReminderMode(*value.ReminderMode)
		if err != nil {
			return models.UpdateTaskIn{}, err
		}
		mode = pointer.To(parsed)
	}

	in := models.UpdateTaskIn{IsProject: value.IsProject, Title: value.Title, Description: value.Description, ListID: value.ListID, ParentID: value.ParentID, DeadlineDate: value.DeadlineDate, DeadlineAt: value.DeadlineAt, PlannedAt: value.PlannedAt, DurationMinutes: value.DurationMinutes, ReminderMode: mode, ReminderMinutesBefore: value.ReminderMinutesBefore, TagIDs: value.TagIDs, ClearDescription: pointer.Get(value.ClearDescription), ClearListID: pointer.Get(value.ClearListID), ClearParentID: pointer.Get(value.ClearParentID), ClearDeadlineDate: pointer.Get(value.ClearDeadlineDate), ClearDeadlineAt: pointer.Get(value.ClearDeadlineAt), ClearPlannedAt: pointer.Get(value.ClearPlannedAt), ClearDurationMinutes: pointer.Get(value.ClearDurationMinutes)}
	if in.ClearDescription && in.Description != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearListID && in.ListID != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearParentID && in.ParentID != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearDeadlineDate && in.DeadlineDate != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearDeadlineAt && in.DeadlineAt != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearPlannedAt && in.PlannedAt != nil {
		return in, apperr.ErrValidation()
	}
	if in.ClearDurationMinutes && in.DurationMinutes != nil {
		return in, apperr.ErrValidation()
	}
	if in.Title != nil {
		if err := models.ValidateName(*in.Title); err != nil {
			return in, err
		}
	}
	return in, nil
}
