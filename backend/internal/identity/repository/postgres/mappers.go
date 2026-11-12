package postgres

import "github.com/alnoi/locked-in/backend/internal/identity/models"

func entityToModel(value entity) models.User {
	return models.User{ID: value.ID, Username: value.Username, TimeZone: value.TimeZone, CreatedAt: value.CreatedAt}
}
func entitiesToModels(values []entity) []models.User {
	result := make([]models.User, 0, len(values))
	for _, value := range values {
		result = append(result, entityToModel(value))
	}
	return result
}
