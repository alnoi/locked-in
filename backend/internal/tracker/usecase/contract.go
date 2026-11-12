package usecase

import (
	"context"

	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

type boardRepository interface {
	EnsureGeneralBoard(context.Context, *uuid.UUID) error
	GetBoards(context.Context, models.GetBoardsFilters) ([]models.Board, error)
	GetBoardsCount(context.Context, models.GetBoardsFilters) (int, error)
	CreateBoard(context.Context, *models.CreateBoardIn) (models.Board, error)
	UpdateBoard(context.Context, *uuid.UUID, *models.UpdateBoardIn) (models.Board, error)
	SoftDeleteBoard(context.Context, models.DeleteBoardFilters) (int64, error)
}
type listRepository interface {
	GetLists(context.Context, models.GetListsFilters) ([]models.List, error)
	GetListsCount(context.Context, models.GetListsFilters) (int, error)
	CreateList(context.Context, *models.CreateListIn) (models.List, error)
	UpdateList(context.Context, *uuid.UUID, *models.UpdateListIn) (models.List, error)
	SoftDeleteList(context.Context, models.DeleteListFilters) (int64, error)
}
type tagRepository interface {
	GetTags(context.Context, models.GetTagsFilters) ([]models.Tag, error)
	GetTagsCount(context.Context, models.GetTagsFilters) (int, error)
	CreateTag(context.Context, *models.CreateTagIn) (models.Tag, error)
	UpdateTag(context.Context, *uuid.UUID, *models.UpdateTagIn) (models.Tag, error)
	SoftDeleteTag(context.Context, models.DeleteTagFilters) (int64, error)
}
type taskRepository interface {
	GetTasks(context.Context, models.GetTasksFilters) ([]models.Task, error)
	GetTasksCount(context.Context, models.GetTasksFilters) (int, error)
	CreateTask(context.Context, *models.CreateTaskIn) (models.Task, error)
	UpdateTask(context.Context, *uuid.UUID, *models.UpdateTaskIn) (models.Task, error)
	SoftDeleteTask(context.Context, models.DeleteTaskFilters) (int64, error)
	SetTaskCompleted(context.Context, *uuid.UUID, *models.SetTaskCompletedIn) (models.Task, error)
}
type commentRepository interface {
	GetComments(context.Context, models.GetCommentsFilters) ([]models.Comment, error)
	GetCommentsCount(context.Context, models.GetCommentsFilters) (int, error)
	CreateComment(context.Context, *models.CreateCommentIn) (models.Comment, error)
	UpdateComment(context.Context, *uuid.UUID, *models.UpdateCommentIn) (models.Comment, error)
	SoftDeleteComment(context.Context, models.DeleteCommentFilters) (int64, error)
}
type linksRepository interface {
	LockOwner(context.Context, *uuid.UUID) error
	SetTaskTags(context.Context, *models.SetTagsIn) error
	SetBoardTags(context.Context, *models.SetTagsIn) error
}
type transactionManager interface {
	WithinTransaction(context.Context, func(context.Context) error) error
}
