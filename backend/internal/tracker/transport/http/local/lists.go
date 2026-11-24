package local

import (
	tracker_genapi "github.com/alnoi/locked-in/backend/generated/service/tracker"
	"github.com/alnoi/locked-in/backend/internal/app/apperr"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func (h *Handlers) GetLists(c *gin.Context, params tracker_genapi.GetListsParams) {
	filters, err := mapGetLists(params)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.GetLists(c.Request.Context(), h.actor(), filters)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapListsToOut(out))
}
func (h *Handlers) GetList(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.GetList(c.Request.Context(), h.actor(), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapListToOut(out))
}
func (h *Handlers) CreateList(c *gin.Context) {
	var request tracker_genapi.CreateListIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapCreateList(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	out, err := h.usecase.CreateList(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(201, mapListToOut(out))
}
func (h *Handlers) UpdateList(c *gin.Context, id uuid.UUID) {
	var request tracker_genapi.UpdateListIn
	if err := decodeJSON(c, &request); err != nil {
		apperr.WriteError(c, err)
		return
	}
	in, err := mapUpdateList(request)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	in.ID = id
	out, err := h.usecase.UpdateList(c.Request.Context(), h.actor(), &in)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapListToOut(out))
}
func (h *Handlers) DeleteList(c *gin.Context, id uuid.UUID) {
	if err := h.usecase.DeleteList(c.Request.Context(), h.actor(), id); err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.Status(204)
}

func (h *Handlers) RestoreList(c *gin.Context, id uuid.UUID) {
	out, err := h.usecase.RestoreList(c.Request.Context(), h.actor(), id)
	if err != nil {
		apperr.WriteError(c, err)
		return
	}
	c.JSON(200, mapListToOut(out))
}
