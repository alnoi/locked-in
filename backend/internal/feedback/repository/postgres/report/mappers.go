package report

import "github.com/alnoi/locked-in/backend/internal/feedback/models"

func entityToModel(value entity) models.BugReportReceipt {
	return models.BugReportReceipt{ID: value.ID, CreatedAt: value.CreatedAt}
}
func entitiesToModels(values []entity) []models.BugReportReceipt {
	result := make([]models.BugReportReceipt, 0, len(values))
	for _, value := range values {
		result = append(result, entityToModel(value))
	}
	return result
}
