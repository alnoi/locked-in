package domain

import (
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func ValidateTaskHierarchy(task models.Task, tasks []models.Task) error {
	if task.ParentID == nil {
		return nil
	}
	if task.IsProject {
		return apperr.ErrConflict()
	}
	if *task.ParentID == task.ID {
		return apperr.ErrValidation()
	}
	found := false
	for _, other := range tasks {
		if other.ID == *task.ParentID {
			found = true
			if other.ParentID != nil {
				return apperr.ErrConflict()
			}
		}
		if other.ParentID != nil && *other.ParentID == task.ID {
			return apperr.ErrConflict()
		}
	}
	if !found {
		return apperr.ErrNotFound()
	}
	return nil
}
func ValidateBoardHierarchy(board models.Board, boards []models.Board) error {
	if board.ParentID == nil {
		if len(board.TagIDs) > 0 || board.FilterCompleted != nil {
			return apperr.ErrValidation()
		}
		return nil
	}
	byID := make(map[uuid.UUID]models.Board, len(boards))
	for _, other := range boards {
		byID[other.ID] = other
	}
	visited := map[uuid.UUID]struct{}{board.ID: {}}
	parentID := *board.ParentID
	for {
		if _, exists := visited[parentID]; exists {
			return apperr.ErrConflict()
		}
		visited[parentID] = struct{}{}
		parent, exists := byID[parentID]
		if !exists {
			return apperr.ErrNotFound()
		}
		if parent.ParentID == nil {
			return nil
		}
		parentID = *parent.ParentID
	}
}
func ResolveBoardSelection(id uuid.UUID, boards []models.Board) (models.BoardSelection, error) {
	byID := make(map[uuid.UUID]models.Board, len(boards))
	for _, board := range boards {
		byID[board.ID] = board
	}
	visited := map[uuid.UUID]struct{}{}
	selection := models.BoardSelection{}
	seenTags := map[uuid.UUID]struct{}{}
	for {
		if _, exists := visited[id]; exists {
			return selection, apperr.ErrConflict()
		}
		visited[id] = struct{}{}
		board, exists := byID[id]
		if !exists {
			return selection, apperr.ErrNotFound()
		}
		for _, tagID := range board.TagIDs {
			if _, seen := seenTags[tagID]; !seen {
				selection.TagIDs = append(selection.TagIDs, tagID)
				seenTags[tagID] = struct{}{}
			}
		}
		if board.FilterCompleted != nil {
			if selection.Completed != nil && *selection.Completed != *board.FilterCompleted {
				selection.MatchNone = true
			}
			selection.Completed = board.FilterCompleted
		}
		if board.ParentID == nil {
			if board.Code == nil || *board.Code != "general" {
				selection.RootID = &board.ID
			}
			return selection, nil
		}
		id = *board.ParentID
	}
}
