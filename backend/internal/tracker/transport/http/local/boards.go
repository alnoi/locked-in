package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	apphttp "github.com/alnoi/locked-in/backend/internal/app/http"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func (h *Handlers) GetBoards(c *gin.Context, params tracker_genapi.GetBoardsParams) {
	filters, err := mapGetBoards(params)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.GetBoards(c.Request.Context(), h.actor(c), filters)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapBoardsToOut(out))
}
func (h *Handlers) GetBoard(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.GetBoard(c.Request.Context(), h.actor(c), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapBoardToOut(out))
}
func (h *Handlers) CreateBoard(c *gin.Context) {
	var request tracker_genapi.CreateBoardIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateBoard(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.CreateBoard(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapBoardToOut(out))
}
func (h *Handlers) UpdateBoard(c *gin.Context, id uuid.UUID) {
	var request tracker_genapi.UpdateBoardIn
	if err := apphttp.DecodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapUpdateBoard(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	in.ID = id
	out, err := h.usecase.UpdateBoard(c.Request.Context(), h.actor(c), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapBoardToOut(out))
}
func (h *Handlers) DeleteBoard(c *gin.Context, id uuid.UUID) {
	if err := h.usecase.DeleteBoard(c.Request.Context(), h.actor(c), id); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}

func (h *Handlers) RestoreBoard(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.RestoreBoard(c.Request.Context(), h.actor(c), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapBoardToOut(out))
}
