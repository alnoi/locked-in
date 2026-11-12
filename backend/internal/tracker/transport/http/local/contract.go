package local

import (
	"context"

	identity "github.com/alnoi/locked-in/backend/internal/identity/models"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/google/uuid"
)

type trackerUseCase interface {
	GetBoards(context.Context, identity.Actor, models.GetBoardsFilters) (models.GetBoardsOut, error)
	GetBoard(context.Context, identity.Actor, uuid.UUID) (models.Board, error)
	CreateBoard(context.Context, identity.Actor, *models.CreateBoardIn) (models.Board, error)
	UpdateBoard(context.Context, identity.Actor, *models.UpdateBoardIn) (models.Board, error)
	DeleteBoard(context.Context, identity.Actor, uuid.UUID) error
	GetLists(context.Context, identity.Actor, models.GetListsFilters) (models.GetListsOut, error)
	GetList(context.Context, identity.Actor, uuid.UUID) (models.List, error)
	CreateList(context.Context, identity.Actor, *models.CreateListIn) (models.List, error)
	UpdateList(context.Context, identity.Actor, *models.UpdateListIn) (models.List, error)
	DeleteList(context.Context, identity.Actor, uuid.UUID) error
	GetTags(context.Context, identity.Actor, models.GetTagsFilters) (models.GetTagsOut, error)
	GetTag(context.Context, identity.Actor, uuid.UUID) (models.Tag, error)
	CreateTag(context.Context, identity.Actor, *models.CreateTagIn) (models.Tag, error)
	UpdateTag(context.Context, identity.Actor, *models.UpdateTagIn) (models.Tag, error)
	DeleteTag(context.Context, identity.Actor, uuid.UUID) error
	GetTasks(context.Context, identity.Actor, models.GetTasksFilters) (models.GetTasksOut, error)
	GetTask(context.Context, identity.Actor, uuid.UUID) (models.Task, error)
	CreateTask(context.Context, identity.Actor, *models.CreateTaskIn) (models.Task, error)
	UpdateTask(context.Context, identity.Actor, *models.UpdateTaskIn) (models.Task, error)
	DeleteTask(context.Context, identity.Actor, uuid.UUID) error
	GetComments(context.Context, identity.Actor, models.GetCommentsFilters) (models.GetCommentsOut, error)
	GetComment(context.Context, identity.Actor, uuid.UUID) (models.Comment, error)
	CreateComment(context.Context, identity.Actor, *models.CreateCommentIn) (models.Comment, error)
	UpdateComment(context.Context, identity.Actor, *models.UpdateCommentIn) (models.Comment, error)
	DeleteComment(context.Context, identity.Actor, uuid.UUID) error
	SetTaskCompleted(context.Context, identity.Actor, *models.SetTaskCompletedIn) (models.Task, error)
}
