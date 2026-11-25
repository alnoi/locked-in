package task_order

import "github.com/alnoi/locked-in/backend/internal/tracker/models"

func entityToModel(value entity) models.TaskOrder {
	return models.TaskOrder{TaskIDs: value.TaskIDs, Revision: value.Revision}
}
func entitiesToModels(values []entity) []models.TaskOrder {
	result := make([]models.TaskOrder, 0, len(values))
	for _, value := range values {
		result = append(result, entityToModel(value))
	}
	return result
}
