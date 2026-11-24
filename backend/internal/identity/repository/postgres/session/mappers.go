package session

import "github.com/alnoi/locked-in/backend/internal/identity/models"

func entityToModel(value entity) models.Session {
	return models.Session{ID: value.ID, UserID: value.UserID, ExpiresAt: value.ExpiresAt}
}
func entitiesToModels(values []entity) []models.Session {
	result := make([]models.Session, 0, len(values))
	for _, value := range values {
		result = append(result, entityToModel(value))
	}
	return result
}
