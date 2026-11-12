package tag

import (
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func entityToModel(row entity) models.Tag {
	return models.Tag{ID: row.ID, OwnerID: row.OwnerID, Name: row.Name, Color: row.Color, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}
func entitiesToModels(rows []entity) []models.Tag {
	result := make([]models.Tag, 0, len(rows))
	for _, row := range rows {
		result = append(result, entityToModel(row))
	}
	return result
}
