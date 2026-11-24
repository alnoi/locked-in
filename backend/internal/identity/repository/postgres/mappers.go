package postgres

import "github.com/alnoi/locked-in/backend/internal/identity/models"

func entityToModel(value entity) models.User {
	return models.User{AvatarEmoji: value.AvatarEmoji, ID: value.ID, Username: value.Username, TimeZone: value.TimeZone, CreatedAt: value.CreatedAt}
}
func entitiesToModels(values []entity) []models.User {
	result := make([]models.User, 0, len(values))
	for _, value := range values {
		result = append(result, entityToModel(value))
	}
	return result
}

func credentialsToModels(values []credentialsEntity) []models.UserCredentials {
	result := make([]models.UserCredentials, 0, len(values))
	for _, value := range values {
		result = append(result, models.UserCredentials{User: entityToModel(value.entity), PasswordHash: value.PasswordHash})
	}
	return result
}
