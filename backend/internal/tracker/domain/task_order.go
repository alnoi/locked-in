package domain

import (
	"slices"
	"strings"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func NormalizeTaskOrder(tasks []models.Task, stored []uuid.UUID) []uuid.UUID {
	tasks = slices.Clone(tasks)
	slices.SortFunc(tasks, func(left, right models.Task) int {
		if order := left.CreatedAt.Compare(right.CreatedAt); order != 0 {
			return order
		}
		return strings.Compare(left.ID.String(), right.ID.String())
	})
	available := make(map[uuid.UUID]struct{}, len(tasks))
	for _, task := range tasks {
		available[task.ID] = struct{}{}
	}
	ids := make([]uuid.UUID, 0, len(tasks))
	for _, id := range stored {
		if _, exists := available[id]; exists {
			ids = append(ids, id)
			delete(available, id)
		}
	}
	for _, task := range tasks {
		if _, exists := available[task.ID]; exists {
			ids = append(ids, task.ID)
		}
	}
	return ids
}
func MergeTaskOrder(current, selected []uuid.UUID) ([]uuid.UUID, error) {
	available := make(map[uuid.UUID]struct{}, len(current))
	for _, id := range current {
		available[id] = struct{}{}
	}
	requested := make(map[uuid.UUID]struct{}, len(selected))
	for _, id := range selected {
		if _, exists := available[id]; !exists {
			return nil, apperr.ErrNotFound()
		}
		requested[id] = struct{}{}
	}
	result := slices.Clone(current)
	index := 0
	for position, id := range result {
		if _, exists := requested[id]; exists {
			result[position] = selected[index]
			index++
		}
	}
	return result, nil
}
