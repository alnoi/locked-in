package board

import (
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
)

func entityToModel(row entity) models.Board {
	return models.Board{Code: row.Code, ID: row.ID, OwnerID: row.OwnerID, Name: row.Name, ParentID: row.ParentID, FilterCompleted: row.FilterCompleted, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt, TagIDs: row.TagIDs}
}
func entitiesToModels(rows []entity) []models.Board {
	result := make([]models.Board, 0, len(rows))
	for _, row := range rows {
		result = append(result, entityToModel(row))
	}
	return result
}
