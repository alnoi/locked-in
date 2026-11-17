package domain

import (
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func ApplyTaskUpdate(value models.Task, in *models.UpdateTaskIn) (models.Task, error) {
	if in.IsProject != nil {
		value.IsProject = *in.IsProject
	}
	if in.Title != nil {
		value.Title = *in.Title
	}
	if in.ClearDescription && in.Description != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearDescription {
		value.Description = nil
	} else if in.Description != nil {
		value.Description = in.Description
	}
	if in.ClearListID && in.ListID != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearListID {
		value.ListID = nil
	} else if in.ListID != nil {
		value.ListID = in.ListID
	}
	if in.ClearParentID && in.ParentID != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearParentID {
		value.ParentID = nil
	} else if in.ParentID != nil {
		value.ParentID = in.ParentID
	}
	if in.ClearDeadlineDate && in.DeadlineDate != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearDeadlineDate {
		value.DeadlineDate = nil
	} else if in.DeadlineDate != nil {
		value.DeadlineDate = in.DeadlineDate
	}
	if in.ClearDeadlineAt && in.DeadlineAt != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearDeadlineAt {
		value.DeadlineAt = nil
	} else if in.DeadlineAt != nil {
		value.DeadlineAt = in.DeadlineAt
	}
	if in.ClearPlannedAt && in.PlannedAt != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearPlannedAt {
		value.PlannedAt = nil
	} else if in.PlannedAt != nil {
		value.PlannedAt = in.PlannedAt
	}
	if in.ClearDurationMinutes && in.DurationMinutes != nil {
		return value, apperr.ErrValidation()
	}
	if in.ClearDurationMinutes {
		value.DurationMinutes = nil
	} else if in.DurationMinutes != nil {
		value.DurationMinutes = in.DurationMinutes
	}
	if in.ReminderMode != nil {
		value.ReminderMode = *in.ReminderMode
	}
	if in.ReminderMinutesBefore != nil {
		value.ReminderMinutesBefore = *in.ReminderMinutesBefore
	}
	if in.TagIDs != nil {
		value.TagIDs = *in.TagIDs
	}
	return value, nil
}
