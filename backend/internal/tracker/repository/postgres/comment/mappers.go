package comment

import (
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func entityToModel(row entity) models.Comment {
	return models.Comment{ID: row.ID, OwnerID: row.OwnerID, TaskID: row.TaskID, Text: row.Text, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}
func entitiesToModels(rows []entity) []models.Comment {
	result := make([]models.Comment, 0, len(rows))
	for _, row := range rows {
		result = append(result, entityToModel(row))
	}
	return result
}
