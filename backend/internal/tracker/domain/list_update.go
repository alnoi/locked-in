package domain

import "github.com/alnoi/locked-in/backend/internal/tracker/models"

func ApplyListUpdate(value models.List, in *models.UpdateListIn) (models.List, error) {
	if in.Name != nil {
		value.Name = *in.Name
	}
	if in.BoardID != nil {
		value.BoardID = *in.BoardID
	}
	return value, nil
}
