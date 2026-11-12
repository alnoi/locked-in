package task

import (
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func entityToModel(row entity) models.Task {
	var date *string
	if row.DeadlineDate != nil {
		value := row.DeadlineDate.Format("2006-01-02")
		date = &value
	}
	return models.Task{ID: row.ID, OwnerID: row.OwnerID, Title: row.Title, Description: row.Description, ListID: row.ListID, ParentID: row.ParentID, DeadlineDate: date, DeadlineAt: row.DeadlineAt, PlannedAt: row.PlannedAt, DurationMinutes: row.DurationMinutes, ReminderMode: row.ReminderMode, ReminderMinutesBefore: row.ReminderMinutesBefore, Completed: row.Completed, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt, TagIDs: row.TagIDs}
}
func entitiesToModels(rows []entity) []models.Task {
	result := make([]models.Task, 0, len(rows))
	for _, row := range rows {
		result = append(result, entityToModel(row))
	}
	return result
}
