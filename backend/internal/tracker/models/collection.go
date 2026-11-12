package models

import (
	"time"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
)

type CollectionQuery struct {
	SortBy        *string
	SortDesc      *int
	CreatedAtFrom *time.Time
	CreatedAtTo   *time.Time
}

func ValidateCollectionQuery(query CollectionQuery, allowed []string) error {
	if query.SortDesc != nil && *query.SortDesc != 0 && *query.SortDesc != 1 {
		return apperr.ErrValidation()
	}
	if query.SortBy != nil {
		found := false
		for _, field := range allowed {
			if field == *query.SortBy {
				found = true
			}
		}
		if !found {
			return apperr.ErrValidation()
		}
	}
	if query.CreatedAtFrom != nil && query.CreatedAtTo != nil && !query.CreatedAtFrom.Before(*query.CreatedAtTo) {
		return apperr.ErrValidation()
	}
	return nil
}
