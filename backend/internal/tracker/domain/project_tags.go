package domain

import (
	"slices"

	"github.com/google/uuid"
)

func InheritProjectTags(tags, projectTags []uuid.UUID) []uuid.UUID {
	result := slices.Clone(tags)
	for _, tagID := range projectTags {
		if !slices.Contains(result, tagID) {
			result = append(result, tagID)
		}
	}
	return result
}
