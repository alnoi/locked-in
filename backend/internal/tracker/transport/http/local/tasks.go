package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/alnoi/locked-in/backend/internal/tracker/models"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func (h *Handlers) GetTasks(c *gin.Context, params tracker_genapi.GetTasksParams) {
	filters, err := mapGetTasks(params)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.GetTasks(c.Request.Context(), h.actor(c), filters)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTasksToOut(out))
}
func (h *Handlers) GetTask(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.GetTask(c.Request.Context(), h.actor(c), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskToOut(out))
}
func (h *Handlers) CreateTask(c *gin.Context) {
	var request tracker_genapi.CreateTaskIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateTask(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.CreateTask(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapTaskToOut(out))
}
func (h *Handlers) UpdateTask(c *gin.Context, id uuid.UUID) {
	var request tracker_genapi.UpdateTaskIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapUpdateTask(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	in.ID = id
	out, err := h.usecase.UpdateTask(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskToOut(out))
}
func (h *Handlers) DeleteTask(c *gin.Context, id uuid.UUID) {
	if err := h.usecase.DeleteTask(c.Request.Context(), h.actor(c), id); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}
func (h *Handlers) CompleteTask(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.SetTaskCompleted(c.Request.Context(), h.actor(c), &models.SetTaskCompletedIn{ID: id, Completed: true})
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskToOut(out))
}
func (h *Handlers) ReopenTask(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.SetTaskCompleted(c.Request.Context(), h.actor(c), &models.SetTaskCompletedIn{ID: id, Completed: false})
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskToOut(out))
}

func (h *Handlers) RestoreTask(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.RestoreTask(c.Request.Context(), h.actor(c), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapTaskToOut(out))
}
