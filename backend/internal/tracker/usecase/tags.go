package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetTags(ctx context.Context, scope *uuid.UUID, filters models.GetTagsFilters) (models.GetTagsOut, error) {
	filters.Scope = scope
	items, err := u.dependencies.Tags.GetTags(ctx, filters)
	if err != nil {
		return models.GetTagsOut{}, err
	}
	total, err := u.dependencies.Tags.GetTagsCount(ctx, filters)
	if err != nil {
		return models.GetTagsOut{}, err
	}
	return models.GetTagsOut{Items: items, Total: total}, nil
}
func (u *UseCase) GetTag(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.Tag, error) {
	values, err := u.dependencies.Tags.GetTags(ctx, models.GetTagsFilters{ID: &id, Scope: scope})
	if err != nil {
		return models.Tag{}, err
	}
	if len(values) == 0 {
		return models.Tag{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
func (u *UseCase) CreateTag(ctx context.Context, scope *uuid.UUID, in *models.CreateTagIn) (models.Tag, error) {
	var result models.Tag
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		in.OwnerID = *scope
		value := models.Tag{Name: in.Name, Color: in.Color}
		if err := u.validateTag(ctx, scope, value); err != nil {
			return err
		}
		created, err := u.dependencies.Tags.CreateTag(ctx, in)
		if err != nil {
			return err
		}
		result = created
		return nil
	})
	return result, err
}
func (u *UseCase) UpdateTag(ctx context.Context, scope *uuid.UUID, in *models.UpdateTagIn) (models.Tag, error) {
	var result models.Tag
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetTag(ctx, scope, in.ID)
		if err != nil {
			return err
		}
		value, err := domain.ApplyTagUpdate(current, in)
		if err != nil {
			return err
		}
		if err := u.validateTag(ctx, scope, value); err != nil {
			return err
		}
		updated, err := u.dependencies.Tags.UpdateTag(ctx, scope, in)
		if err != nil {
			return err
		}
		result = updated
		return nil
	})
	return result, err
}
func (u *UseCase) DeleteTag(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	return u.mutate(ctx, scope, func(ctx context.Context) error {
		tasks, err := u.dependencies.Tasks.GetTasksCount(ctx, models.GetTasksFilters{Scope: scope, TagIDs: []uuid.UUID{id}})
		if err != nil {
			return err
		}
		if tasks > 0 {
			return apperr.ErrConflict()
		}
		boards, err := u.dependencies.Boards.GetBoards(ctx, models.GetBoardsFilters{Scope: scope})
		if err != nil {
			return err
		}
		for _, board := range boards {
			for _, tagID := range board.TagIDs {
				if tagID == id {
					return apperr.ErrConflict()
				}
			}
		}
		affected, err := u.dependencies.Tags.SoftDeleteTag(ctx, models.DeleteTagFilters{ID: &id, Scope: scope})
		if err != nil {
			return err
		}
		if affected == 0 {
			return apperr.ErrNotFound()
		}
		return nil
	})
}
func (u *UseCase) validateTag(ctx context.Context, scope *uuid.UUID, value models.Tag) error {
	if err := models.ValidateName(value.Name); err != nil {
		return err
	}
	return models.ValidateColor(value.Color)
}
