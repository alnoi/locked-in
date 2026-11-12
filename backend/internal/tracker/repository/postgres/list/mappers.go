package list

import "github.com/alnoi/locked-in/backend/internal/tracker/models"

func entityToModel(row entity) models.List {
	return models.List{ID: row.ID, OwnerID: row.OwnerID, Name: row.Name, BoardID: row.BoardID, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt}
}
func entitiesToModels(rows []entity) []models.List {
	result := make([]models.List, 0, len(rows))
	for _, row := range rows {
		result = append(result, entityToModel(row))
	}
	return result
}
