package usecase

import (
	"context"

	identity "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

type AuthorizedUseCase struct{ core *UseCase }

func NewAuthorized(core *UseCase) *AuthorizedUseCase { return &AuthorizedUseCase{core: core} }
func (u *AuthorizedUseCase) GetBoards(ctx context.Context, actor identity.Actor, in models.GetBoardsFilters) (models.GetBoardsOut, error) {
	if err := actor.Require(); err != nil {
		return models.GetBoardsOut{}, err
	}
	return u.core.GetBoards(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) GetBoard(ctx context.Context, actor identity.Actor, in uuid.UUID) (models.Board, error) {
	if err := actor.Require(); err != nil {
		return models.Board{}, err
	}
	return u.core.GetBoard(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) CreateBoard(ctx context.Context, actor identity.Actor, in *models.CreateBoardIn) (models.Board, error) {
	if err := actor.Require(); err != nil {
		return models.Board{}, err
	}
	return u.core.CreateBoard(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) UpdateBoard(ctx context.Context, actor identity.Actor, in *models.UpdateBoardIn) (models.Board, error) {
	if err := actor.Require(); err != nil {
		return models.Board{}, err
	}
	return u.core.UpdateBoard(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) DeleteBoard(ctx context.Context, actor identity.Actor, id uuid.UUID) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.DeleteBoard(ctx, actor.Scope(), id)
}
func (u *AuthorizedUseCase) GetLists(ctx context.Context, actor identity.Actor, in models.GetListsFilters) (models.GetListsOut, error) {
	if err := actor.Require(); err != nil {
		return models.GetListsOut{}, err
	}
	return u.core.GetLists(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) GetList(ctx context.Context, actor identity.Actor, in uuid.UUID) (models.List, error) {
	if err := actor.Require(); err != nil {
		return models.List{}, err
	}
	return u.core.GetList(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) CreateList(ctx context.Context, actor identity.Actor, in *models.CreateListIn) (models.List, error) {
	if err := actor.Require(); err != nil {
		return models.List{}, err
	}
	return u.core.CreateList(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) UpdateList(ctx context.Context, actor identity.Actor, in *models.UpdateListIn) (models.List, error) {
	if err := actor.Require(); err != nil {
		return models.List{}, err
	}
	return u.core.UpdateList(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) DeleteList(ctx context.Context, actor identity.Actor, id uuid.UUID) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.DeleteList(ctx, actor.Scope(), id)
}
func (u *AuthorizedUseCase) GetTags(ctx context.Context, actor identity.Actor, in models.GetTagsFilters) (models.GetTagsOut, error) {
	if err := actor.Require(); err != nil {
		return models.GetTagsOut{}, err
	}
	return u.core.GetTags(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) GetTag(ctx context.Context, actor identity.Actor, in uuid.UUID) (models.Tag, error) {
	if err := actor.Require(); err != nil {
		return models.Tag{}, err
	}
	return u.core.GetTag(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) CreateTag(ctx context.Context, actor identity.Actor, in *models.CreateTagIn) (models.Tag, error) {
	if err := actor.Require(); err != nil {
		return models.Tag{}, err
	}
	return u.core.CreateTag(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) UpdateTag(ctx context.Context, actor identity.Actor, in *models.UpdateTagIn) (models.Tag, error) {
	if err := actor.Require(); err != nil {
		return models.Tag{}, err
	}
	return u.core.UpdateTag(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) DeleteTag(ctx context.Context, actor identity.Actor, id uuid.UUID) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.DeleteTag(ctx, actor.Scope(), id)
}
func (u *AuthorizedUseCase) GetTasks(ctx context.Context, actor identity.Actor, in models.GetTasksFilters) (models.GetTasksOut, error) {
	if err := actor.Require(); err != nil {
		return models.GetTasksOut{}, err
	}
	return u.core.GetTasks(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) GetTask(ctx context.Context, actor identity.Actor, in uuid.UUID) (models.Task, error) {
	if err := actor.Require(); err != nil {
		return models.Task{}, err
	}
	return u.core.GetTask(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) CreateTask(ctx context.Context, actor identity.Actor, in *models.CreateTaskIn) (models.Task, error) {
	if err := actor.Require(); err != nil {
		return models.Task{}, err
	}
	return u.core.CreateTask(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) UpdateTask(ctx context.Context, actor identity.Actor, in *models.UpdateTaskIn) (models.Task, error) {
	if err := actor.Require(); err != nil {
		return models.Task{}, err
	}
	return u.core.UpdateTask(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) DeleteTask(ctx context.Context, actor identity.Actor, id uuid.UUID) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.DeleteTask(ctx, actor.Scope(), id)
}
func (u *AuthorizedUseCase) GetComments(ctx context.Context, actor identity.Actor, in models.GetCommentsFilters) (models.GetCommentsOut, error) {
	if err := actor.Require(); err != nil {
		return models.GetCommentsOut{}, err
	}
	return u.core.GetComments(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) GetComment(ctx context.Context, actor identity.Actor, in uuid.UUID) (models.Comment, error) {
	if err := actor.Require(); err != nil {
		return models.Comment{}, err
	}
	return u.core.GetComment(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) CreateComment(ctx context.Context, actor identity.Actor, in *models.CreateCommentIn) (models.Comment, error) {
	if err := actor.Require(); err != nil {
		return models.Comment{}, err
	}
	return u.core.CreateComment(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) UpdateComment(ctx context.Context, actor identity.Actor, in *models.UpdateCommentIn) (models.Comment, error) {
	if err := actor.Require(); err != nil {
		return models.Comment{}, err
	}
	return u.core.UpdateComment(ctx, actor.Scope(), in)
}
func (u *AuthorizedUseCase) DeleteComment(ctx context.Context, actor identity.Actor, id uuid.UUID) error {
	if err := actor.Require(); err != nil {
		return err
	}
	return u.core.DeleteComment(ctx, actor.Scope(), id)
}
func (u *AuthorizedUseCase) SetTaskCompleted(ctx context.Context, actor identity.Actor, in *models.SetTaskCompletedIn) (models.Task, error) {
	if err := actor.Require(); err != nil {
		return models.Task{}, err
	}
	return u.core.SetTaskCompleted(ctx, actor.Scope(), in)
}
