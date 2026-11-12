package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetBoards(ctx context.Context, scope *uuid.UUID, filters models.GetBoardsFilters) (models.GetBoardsOut, error) {
	filters.Scope = scope
	items, err := u.dependencies.Boards.GetBoards(ctx, filters)
	if err != nil {
		return models.GetBoardsOut{}, err
	}
	total, err := u.dependencies.Boards.GetBoardsCount(ctx, filters)
	if err != nil {
		return models.GetBoardsOut{}, err
	}
	return models.GetBoardsOut{Items: items, Total: total}, nil
}
func (u *UseCase) GetBoard(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.Board, error) {
	values, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{ID: &id, Scope: scope})
	if err != nil {
		return models.Board{}, err
	}
	if len(values) == 0 {
		return models.Board{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
func (u *UseCase) CreateBoard(ctx context.Context, scope *uuid.UUID, in *models.CreateBoardIn) (models.Board, error) {
	var result models.Board
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		in.OwnerID = *scope
		value := models.Board{Name: in.Name, ParentID: in.ParentID, FilterCompleted: in.FilterCompleted, TagIDs: in.TagIDs}
		if err := u.validateBoard(ctx, scope, value); err != nil {
			return err
		}
		created, err := u.dependencies.Boards.CreateBoard(ctx, in)
		if err != nil {
			return err
		}
		if err := u.dependencies.Links.SetBoardTags(ctx, &models.SetTagsIn{OwnerID: *scope, ID: created.ID, TagIDs: in.TagIDs}); err != nil {
			return err
		}
		created.TagIDs = in.TagIDs
		if created.TagIDs == nil {
			created.TagIDs = []uuid.UUID{}
		}
		result = created
		return nil
	})
	return result, err
}
func (u *UseCase) UpdateBoard(ctx context.Context, scope *uuid.UUID, in *models.UpdateBoardIn) (models.Board, error) {
	var result models.Board
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetBoard(ctx, scope, in.ID)
		if err != nil {
			return err
		}
		value, err := domain.ApplyBoardUpdate(current, in)
		if err != nil {
			return err
		}
		if err := u.validateBoard(ctx, scope, value); err != nil {
			return err
		}
		updated, err := u.dependencies.Boards.UpdateBoard(ctx, scope, in)
		if err != nil {
			return err
		}
		if in.TagIDs != nil {
			if err := u.dependencies.Links.SetBoardTags(ctx, &models.SetTagsIn{OwnerID: *scope, ID: in.ID, TagIDs: *in.TagIDs}); err != nil {
				return err
			}
			updated.TagIDs = *in.TagIDs
		}
		result = updated
		return nil
	})
	return result, err
}
func (u *UseCase) DeleteBoard(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	return u.mutate(ctx, scope, func(ctx context.Context) error {
		board, err := u.GetBoard(ctx, scope, id)
		if err != nil {
			return err
		}
		if board.Code != nil {
			return apperr.ErrConflict()
		}
		boards, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{Scope: scope})
		if err != nil {
			return err
		}
		for _, child := range boards {
			if child.ParentID != nil && *child.ParentID == id {
				return apperr.ErrConflict()
			}
		}
		count, err := u.dependencies.Lists.GetListsCount(ctx, models.GetListsFilters{Scope: scope, BoardID: &id})
		if err != nil {
			return err
		}
		if count > 0 {
			return apperr.ErrConflict()
		}
		affected, err := u.dependencies.Boards.SoftDeleteBoard(ctx, models.DeleteBoardFilters{ID: &id, Scope: scope})
		if err != nil {
			return err
		}
		if affected == 0 {
			return apperr.ErrNotFound()
		}
		return nil
	})
}
func (u *UseCase) validateBoard(ctx context.Context, scope *uuid.UUID, value models.Board) error {
	if err := models.ValidateName(value.Name); err != nil {
		return err
	}
	if value.Code != nil && (value.ParentID != nil || len(value.TagIDs) > 0 || value.FilterCompleted != nil) {
		return apperr.ErrValidation()
	}
	if err := u.validateTags(ctx, scope, value.TagIDs); err != nil {
		return err
	}
	boards, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{Scope: scope})
	if err != nil {
		return err
	}
	if value.ParentID != nil && value.ID != uuid.Nil {
		count, err := u.dependencies.Lists.GetListsCount(ctx, models.GetListsFilters{Scope: scope, BoardID: &value.ID})
		if err != nil {
			return err
		}
		if count > 0 {
			return apperr.ErrConflict()
		}
	}
	return domain.ValidateBoardHierarchy(value, boards)
}
func (u *UseCase) EnsureGeneralBoard(ctx context.Context, scope *uuid.UUID) error {
	return u.dependencies.Boards.EnsureGeneralBoard(ctx, scope)
}
func (u *UseCase) generalBoard(ctx context.Context, scope *uuid.UUID) (models.Board, error) {
	values, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{Scope: scope})
	if err != nil {
		return models.Board{}, err
	}
	for _, board := range values {
		if board.Code != nil && *board.Code == "general" {
			return board, nil
		}
	}
	return models.Board{}, apperr.ErrNotFound()
}
func (u *UseCase) boardSelection(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.BoardSelection, error) {
	values, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{Scope: scope})
	if err != nil {
		return models.BoardSelection{}, err
	}
	return domain.ResolveBoardSelection(id, values)
}
