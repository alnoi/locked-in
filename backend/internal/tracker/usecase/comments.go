package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/alnoi/locked-in/backend/internal/tracker/domain"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

func (u *UseCase) GetComments(ctx context.Context, scope *uuid.UUID, filters models.GetCommentsFilters) (models.GetCommentsOut, error) {
	filters.Scope = scope
	items, err := u.dependencies.Comments.GetComments(ctx, filters)
	if err != nil {
		return models.GetCommentsOut{}, err
	}
	total, err := u.dependencies.Comments.GetCommentsCount(ctx, filters)
	if err != nil {
		return models.GetCommentsOut{}, err
	}
	return models.GetCommentsOut{Items: items, Total: total}, nil
}
func (u *UseCase) GetComment(ctx context.Context, scope *uuid.UUID, id uuid.UUID) (models.Comment, error) {
	values, err := u.dependencies.Comments.GetComments(ctx, models.GetCommentsFilters{ID: &id, Scope: scope})
	if err != nil {
		return models.Comment{}, err
	}
	if len(values) == 0 {
		return models.Comment{}, apperr.ErrNotFound()
	}
	return values[0], nil
}
func (u *UseCase) CreateComment(ctx context.Context, scope *uuid.UUID, in *models.CreateCommentIn) (models.Comment, error) {
	var result models.Comment
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		in.OwnerID = *scope
		value := models.Comment{Text: in.Text, TaskID: in.TaskID}
		if err := u.validateComment(ctx, scope, value); err != nil {
			return err
		}
		created, err := u.dependencies.Comments.CreateComment(ctx, in)
		if err != nil {
			return err
		}
		result = created
		return nil
	})
	return result, err
}
func (u *UseCase) UpdateComment(ctx context.Context, scope *uuid.UUID, in *models.UpdateCommentIn) (models.Comment, error) {
	var result models.Comment
	err := u.mutate(ctx, scope, func(ctx context.Context) error {
		current, err := u.GetComment(ctx, scope, in.ID)
		if err != nil {
			return err
		}
		value, err := domain.ApplyCommentUpdate(current, in)
		if err != nil {
			return err
		}
		if err := u.validateComment(ctx, scope, value); err != nil {
			return err
		}
		updated, err := u.dependencies.Comments.UpdateComment(ctx, scope, in)
		if err != nil {
			return err
		}
		result = updated
		return nil
	})
	return result, err
}
func (u *UseCase) DeleteComment(ctx context.Context, scope *uuid.UUID, id uuid.UUID) error {
	return u.mutate(ctx, scope, func(ctx context.Context) error {
		if _, err := u.GetComment(ctx, scope, id); err != nil {
			return err
		}
		affected, err := u.dependencies.Comments.SoftDeleteComment(ctx, models.DeleteCommentFilters{ID: &id, Scope: scope})
		if err != nil {
			return err
		}
		if affected == 0 {
			return apperr.ErrNotFound()
		}
		return nil
	})
}
func (u *UseCase) validateComment(ctx context.Context, scope *uuid.UUID, value models.Comment) error {
	if err := models.ValidateComment(value.Text); err != nil {
		return err
	}
	_, err := u.GetTask(ctx, scope, value.TaskID)
	return err
}
